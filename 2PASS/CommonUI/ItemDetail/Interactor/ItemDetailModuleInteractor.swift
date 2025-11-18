// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol ItemDetailModuleInteracting: AnyObject {
    func fetchPassword(for itemID: ItemID) -> LoginItemData?
    func fetchTags(for tagIDs: [ItemTagID]) -> [ItemTagData]
    func decryptPassword(for itemID: ItemID) -> String?
    func copy(_ str: String)
    func fetchIconImage(from url: URL) async throws -> Data
    func normalizedURL(for uri: PasswordURI) -> URL?
}

final class ItemDetailModuleInteractor {
    private let itemsInteractor: ItemsInteracting
    private let systemInteractor: SystemInteracting
    private let fileIconInteractor: FileIconInteracting
    private let uriInteractor: URIInteracting
    private let tagInteractor: TagInteracting
    
    init(
        itemsInteractor: ItemsInteracting,
        systemInteractor: SystemInteracting,
        fileIconInteractor: FileIconInteracting,
        uriInteractor: URIInteracting,
        tagInteractor: TagInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.systemInteractor = systemInteractor
        self.fileIconInteractor = fileIconInteractor
        self.uriInteractor = uriInteractor
        self.tagInteractor = tagInteractor
    }
}

extension ItemDetailModuleInteractor: ItemDetailModuleInteracting {
    func fetchPassword(for itemID: ItemID) -> LoginItemData? {
        itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asLoginItem
    }
    
    func decryptPassword(for itemID: ItemID) -> String? {
        switch itemsInteractor.getPasswordEncryptedContents(for: itemID, checkInTrash: false) {
        case .success(let password): return password
        case .failure: return nil
        }
    }
    
    func copy(_ str: String) {
        systemInteractor.copyToClipboard(str)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
    
    func normalizedURL(for uri: PasswordURI) -> URL? {
        guard let normalizedString = uriInteractor.normalize(uri.uri), let url = URL(string: normalizedString) else {
            return nil
        }
        return url
    }
    
    func fetchTags(for tagIDs: [ItemTagID]) -> [ItemTagData] {
        tagInteractor.getTags(by: tagIDs)
            .sorted { $0.name < $1.name }
    }
}
