// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol PasswordsModuleInteracting: AnyObject {
    var hasItems: Bool { get }
    
    var currentPlanItemsLimit: Int { get }
    var canAddPassword: Bool { get }
    var selectAction: PasswordListAction { get }
    
    var currentSortType: SortType { get }
    func setSortType(_ sortType: SortType)
    
    func loadList(contentType: ItemContentType?, tag: ItemTagData?) -> [ItemData]
    func loadList(forServiceIdentifiers serviceURIs: [String], contentType: ItemContentType?, tag: ItemTagData?) -> (suggested: [ItemData], rest: [ItemData])

    var isSearching: Bool { get }
    func setSearchPhrase(_ searchPhrase: String?)
    
    func moveToTrash(_ itemID: ItemID)
    func copyUsername(_ itemID: ItemID) -> Bool
    func copyPassword(_ itemID: ItemID) -> Bool
    func copySecureNote(_ itemID: ItemID) -> Bool
    func copyPaymentCardNumber(_ itemID: ItemID) -> Bool
    func copyPaymentCardSecurityCode(_ itemID: ItemID) -> Bool

    func cachedImage(from url: URL) -> Data?
    func fetchIconImage(from url: URL) async throws -> Data
    
    func normalizedURL(for uri: String) -> URL?
    func listAllTags() -> [ItemTagData]
    func countItemsForTag(_ tagID: ItemTagID) -> Int
}

final class PasswordsModuleInteractor {
    private let itemsInteractor: ItemsInteracting
    private let fileIconInteractor: FileIconInteracting
    private let systemInteractor: SystemInteracting
    private let uriInteractor: URIInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    private let configInteractor: ConfigInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    private let passwordListInteractor: PasswordListInteracting
    private let tagInteractor: TagInteracting
    
    private var searchPhrase: String?
    
    init(
        itemsInteractor: ItemsInteracting,
        fileIconInteractor: FileIconInteracting,
        systemInteractor: SystemInteracting,
        uriInteractor: URIInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting,
        autoFillCredentialsInteractor: AutoFillCredentialsInteracting,
        configInteractor: ConfigInteracting,
        paymentStatusInteractor: PaymentStatusInteracting,
        passwordListInteractor: PasswordListInteracting,
        tagInteractor: TagInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.fileIconInteractor = fileIconInteractor
        self.systemInteractor = systemInteractor
        self.uriInteractor = uriInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
        self.configInteractor = configInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
        self.passwordListInteractor = passwordListInteractor
        self.tagInteractor = tagInteractor
    }
}

extension PasswordsModuleInteractor: PasswordsModuleInteracting {
    
    var hasItems: Bool {
        itemsInteractor.hasItems
    }
    
    var canAddPassword: Bool {
        guard let limit = paymentStatusInteractor.entitlements.itemsLimit else {
            return true
        }
        return itemsInteractor.itemsCount < limit
    }
    
    var currentPlanItemsLimit: Int {
        paymentStatusInteractor.entitlements.itemsLimit ?? Int.max
    }
    
    var selectAction: PasswordListAction {
        configInteractor.defaultPassswordListAction
    }
    
    func loadList(contentType: ItemContentType?, tag: ItemTagData?) -> [ItemData] {
        let contentTypes: [ItemContentType]? = {
            if let contentType {
                return [contentType]
            } else {
                return nil
            }
        }()
        
        return itemsInteractor.listItems(
            searchPhrase: searchPhrase,
            tagId: tag?.id,
            vaultId: nil,
            contentTypes: contentTypes ?? .allKnownTypes,
            sortBy: currentSortType,
            trashed: .no
        )
    }
    
    func loadList(forServiceIdentifiers serviceIdentifiers: [String], contentType: ItemContentType?, tag: ItemTagData?) -> (suggested: [ItemData], rest: [ItemData]) {
        let contentTypes: [ItemContentType]? = {
            if let contentType {
                return [contentType]
            } else {
                return nil
            }
        }()
        
        let allPasswords = itemsInteractor.listItems(searchPhrase: nil, tagId: tag?.tagID, vaultId: nil, contentTypes: contentTypes, sortBy: currentSortType, trashed: .no)
        
        guard serviceIdentifiers.isEmpty == false else {
            return ([], allPasswords)
        }
        
        var suggested: [ItemData] = []
        var rest: [ItemData] = []
        
        for autofillService in serviceIdentifiers {
            for element in allPasswords where Config.autoFillExcludeProtectionLevels.contains(element.protectionLevel) == false {
                if case let .login(loginItem) = element {
                    if let uris = loginItem.content.uris {
                        let isMatch = uris.contains(where: { uri in
                            uriInteractor.isMatch(uri.uri, to: autofillService, rule: uri.match)
                        })
                        
                        if isMatch {
                            suggested.append(element)
                        } else {
                            rest.append(element)
                        }
                    } else {
                        rest.append(element)
                    }
                }
            }
        }
        
        return (suggested, rest)
    }
    
    var isSearching: Bool {
        if let searchPhrase {
            return !searchPhrase.isEmpty
        }
        return false
    }
    
    func setSearchPhrase(_ searchPhrase: String?) {
        self.searchPhrase = searchPhrase
    }
    
    var currentSortType: SortType {
        passwordListInteractor.currentSortType
    }
    
    func setSortType(_ sortType: SortType) {
        passwordListInteractor.setSortType(sortType)
    }
    
    func moveToTrash(_ itemID: ItemID) {
        Log("PasswordsModuleInteractor: Move to trash: \(itemID)", module: .moduleInteractor)
        let deletedPassword = itemsInteractor.getItem(for: itemID, checkInTrash: false)
        itemsInteractor.markAsTrashed(for: itemID)
        itemsInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
        if let loginItem = deletedPassword?.asLoginItem {
            Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                try await autoFillCredentialsInteractor.removeSuggestions(for: loginItem)
            }
        }
    }
    
    func copyUsername(_ itemID: ItemID) -> Bool {
        guard let loginItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asLoginItem,
              let username = loginItem.username
        else {
            return false
        }
        systemInteractor.copyToClipboard(username)
        return true
    }
    
    func copyPassword(_ itemID: ItemID) -> Bool {
        let passwordResult = itemsInteractor.getPasswordEncryptedContents(for: itemID, checkInTrash: false)

        switch passwordResult {
        case .success(let password):
            if let password {
                systemInteractor.copyToClipboard(password)
                return true
            } else {
                return false
            }
        case .failure(.noPassword):
            systemInteractor.copyToClipboard("")
            return true
        case .failure:
            return false
        }
    }
    
    func copySecureNote(_ itemID: ItemID) -> Bool {
        guard let secureNoteItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asSecureNote else {
            return false
        }
        
        guard let noteText = secureNoteItem.content.text else {
            systemInteractor.copyToClipboard("")
            return true
        }
        
        guard let decryptedText = itemsInteractor.decrypt(noteText, isSecureField: true, protectionLevel: secureNoteItem.protectionLevel) else {
            return false
        }
        
        systemInteractor.copyToClipboard(decryptedText)
        return true
    }

    func copyPaymentCardNumber(_ itemID: ItemID) -> Bool {
        guard let paymentCardItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asPaymentCard,
              let cardNumber = paymentCardItem.content.cardNumber,
              let decryptedNumber = itemsInteractor.decrypt(cardNumber, isSecureField: true, protectionLevel: paymentCardItem.protectionLevel)
        else {
            return false
        }
        systemInteractor.copyToClipboard(decryptedNumber)
        return true
    }

    func copyPaymentCardSecurityCode(_ itemID: ItemID) -> Bool {
        guard let paymentCardItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asPaymentCard,
              let securityCode = paymentCardItem.content.securityCode,
              let decryptedCode = itemsInteractor.decrypt(securityCode, isSecureField: true, protectionLevel: paymentCardItem.protectionLevel)
        else {
            return false
        }
        systemInteractor.copyToClipboard(decryptedCode)
        return true
    }

    func cachedImage(from url: URL) -> Data? {
        fileIconInteractor.cachedImage(from: url)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
    
    func normalizedURL(for uri: String) -> URL? {
        guard let normalizedString = uriInteractor.normalize(uri), let url = URL(string: normalizedString) else {
            return nil
        }
        return url
    }
    
    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
            .sorted(by: { $0.name < $1.name })
    }
    
    func countItemsForTag(_ tagID: ItemTagID) -> Int {
        itemsInteractor.getItemCountForTag(tagID: tagID)
    }
}
