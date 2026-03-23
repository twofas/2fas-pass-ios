// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol ShareLinkItemModuleInteracting: AnyObject {
    func fetchItem(for itemID: ItemID) -> ItemData?
    func fetchIconImage(from url: URL) async throws -> Data
    func shareItem(
        id: ItemID,
        password: String?,
        validForSeconds: Int,
        singleUse: Bool
    ) async throws -> URL
    var shareLinkConfig: ShareLinkConfig? { get }
    func saveShareLinkConfig(expirationSeconds: TimeInterval, isOneTimeAccess: Bool)
}

final class ShareLinkItemModuleInteractor: ShareLinkItemModuleInteracting {
    private let itemsInteractor: ItemsInteracting
    private let fileIconInteractor: FileIconInteracting
    private let shareLinkInteractor: ShareLinkInteracting
    private let configInteractor: ConfigInteracting

    init(
        itemsInteractor: ItemsInteracting,
        fileIconInteractor: FileIconInteracting,
        shareLinkInteractor: ShareLinkInteracting,
        configInteractor: ConfigInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.fileIconInteractor = fileIconInteractor
        self.shareLinkInteractor = shareLinkInteractor
        self.configInteractor = configInteractor
    }

    func fetchItem(for itemID: ItemID) -> ItemData? {
        itemsInteractor.getItem(for: itemID, checkInTrash: false)
    }

    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }

    func shareItem(
        id: ItemID,
        password: String?,
        validForSeconds: Int,
        singleUse: Bool
    ) async throws -> URL {
        let exportResult: ShareExportResult
        if let password {
            exportResult = try await shareLinkInteractor.exportItem(id: id, password: password)
        } else {
            exportResult = try await shareLinkInteractor.exportItem(id: id)
        }

        let response = try await shareLinkInteractor.createSecret(
            data: exportResult.encryptedData,
            validForSeconds: validForSeconds,
            singleUse: singleUse
        )

        guard let url = shareLinkInteractor.makeShareURL(
            id: response.id,
            exportResult: exportResult
        ) else {
            throw URLError(.badURL)
        }

        return url
    }

    var shareLinkConfig: ShareLinkConfig? {
        configInteractor.shareLinkConfig
    }

    func saveShareLinkConfig(expirationSeconds: TimeInterval, isOneTimeAccess: Bool) {
        configInteractor.saveShareLinkConfig(
            ShareLinkConfig(expirationSeconds: expirationSeconds, isOneTimeAccess: isOneTimeAccess)
        )
    }
}
