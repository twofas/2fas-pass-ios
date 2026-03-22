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
    func generatePassword() -> String
    var shareLinkConfig: ShareLinkConfig? { get }
    func saveShareLinkConfig(expirationSeconds: TimeInterval, isOneTimeAccess: Bool)
}

final class ShareLinkItemModuleInteractor: ShareLinkItemModuleInteracting {
    private let itemsInteractor: ItemsInteracting
    private let fileIconInteractor: FileIconInteracting
    private let shareServiceInteractor: ShareServiceInteracting
    private let shareLinkInteractor: ShareLinkInteracting
    private let passwordGeneratorInteractor: PasswordGeneratorInteracting
    private let configInteractor: ConfigInteracting

    init(
        itemsInteractor: ItemsInteracting,
        fileIconInteractor: FileIconInteracting,
        shareServiceInteractor: ShareServiceInteracting,
        shareLinkInteractor: ShareLinkInteracting,
        passwordGeneratorInteractor: PasswordGeneratorInteracting,
        configInteractor: ConfigInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.fileIconInteractor = fileIconInteractor
        self.shareServiceInteractor = shareServiceInteractor
        self.shareLinkInteractor = shareLinkInteractor
        self.passwordGeneratorInteractor = passwordGeneratorInteractor
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

        let response = try await shareServiceInteractor.createSecret(
            data: exportResult.encryptedData.base64EncodedString(),
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

    func generatePassword() -> String {
        let config = configInteractor.passwordGeneratorConfig ?? .init(
            length: passwordGeneratorInteractor.prefersPasswordLength,
            hasDigits: true,
            hasUppercase: true,
            hasSpecial: true
        )
        return passwordGeneratorInteractor.generatePassword(using: config)
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
