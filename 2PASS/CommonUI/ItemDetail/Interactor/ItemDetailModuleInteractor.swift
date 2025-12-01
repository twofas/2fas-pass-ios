// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol ItemDetailModuleInteracting: AnyObject {
    func fetchItem(for itemID: ItemID) -> ItemData?
    func fetchTags(for tagIDs: [ItemTagID]) -> [ItemTagData]
    func decryptSecureField(_ data: Data, protectionLevel: ItemProtectionLevel) -> String?
    func decryptPassword(for itemID: ItemID) -> String?
    func copy(_ str: String)
    func fetchIconImage(from url: URL) async throws -> Data
    func normalizedURL(for uri: PasswordURI) -> URL?
    func paymentCardSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int
}

final class ItemDetailModuleInteractor {
    private let itemsInteractor: ItemsInteracting
    private let systemInteractor: SystemInteracting
    private let fileIconInteractor: FileIconInteracting
    private let uriInteractor: URIInteracting
    private let tagInteractor: TagInteracting
    private let paymentCardUtilityInteractor: PaymentCardUtilityInteracting

    init(
        itemsInteractor: ItemsInteracting,
        systemInteractor: SystemInteracting,
        fileIconInteractor: FileIconInteracting,
        uriInteractor: URIInteracting,
        tagInteractor: TagInteracting,
        paymentCardUtilityInteractor: PaymentCardUtilityInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.systemInteractor = systemInteractor
        self.fileIconInteractor = fileIconInteractor
        self.uriInteractor = uriInteractor
        self.tagInteractor = tagInteractor
        self.paymentCardUtilityInteractor = paymentCardUtilityInteractor
    }
}

extension ItemDetailModuleInteractor: ItemDetailModuleInteracting {
    func fetchItem(for itemID: ItemID) -> ItemData? {
        itemsInteractor.getItem(for: itemID, checkInTrash: false)
    }
    
    func decryptSecureField(_ data: Data, protectionLevel: ItemProtectionLevel) -> String? {
        itemsInteractor.decrypt(data, isSecureField: true, protectionLevel: protectionLevel)
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

    func paymentCardSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int {
        paymentCardUtilityInteractor.maxSecurityCodeLength(for: issuer)
    }
}
