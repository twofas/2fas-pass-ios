// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol PasswordsModuleInteracting: AnyObject {
    var isUserLoggedIn: Bool { get }
    var hasItems: Bool { get }
    func hasItems(for contentType: ItemContentType) -> Bool

    var currentPlanItemsLimit: Int { get }
    var canAddPassword: Bool { get }
    var selectAction: PasswordListAction { get }

    var currentSortType: SortType { get }
    func setSortType(_ sortType: SortType)

    func loadList(contentType: ItemContentType?, tag: ItemTagData?, protectionLevel: ItemProtectionLevel?) -> [ItemData]
    func loadList(forServiceIdentifiers serviceURIs: [String], contentType: ItemContentType?, tag: ItemTagData?, protectionLevel: ItemProtectionLevel?) -> (suggested: [ItemData], rest: [ItemData])

    var isSearching: Bool { get }
    func setSearchPhrase(_ searchPhrase: String?)

    func moveToTrash(_ itemID: ItemID)
    func copyUsername(_ itemID: ItemID) -> Bool
    func copyPassword(_ itemID: ItemID) -> Bool
    func copySecureNote(_ itemID: ItemID) -> Bool
    func copyPaymentCardNumber(_ itemID: ItemID) -> Bool
    func copyPaymentCardSecurityCode(_ itemID: ItemID) -> Bool
    func copyWiFiSSID(_ itemID: ItemID) -> Bool
    func copyWiFiPassword(_ itemID: ItemID) -> Bool

    func cachedImage(from url: URL) -> Data?
    func fetchIconImage(from url: URL) async throws -> Data

    func normalizedURL(for uri: String) -> URL?
    func listAllTags() -> [ItemTagData]
    func getTag(for tagID: ItemTagID) -> ItemTagData?
    func countItemsForTag(_ tagID: ItemTagID) -> Int
    func countItemsForProtectionLevel(_ protectionLevel: ItemProtectionLevel) -> Int
    func updateProtectionLevel(_ protectionLevel: ItemProtectionLevel, for itemIDs: [ItemID]) throws(ItemsInteractorSaveError)
    func applyTagChanges(to itemIDs: [ItemID], tagsToAdd: Set<ItemTagID>, tagsToRemove: Set<ItemTagID>) throws
}

final class PasswordsModuleInteractor {
    private let securityInteractor: SecurityInteracting
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
        securityInteractor: SecurityInteracting,
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
        self.securityInteractor = securityInteractor
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

    var isUserLoggedIn: Bool {
        securityInteractor.isUserLoggedIn
    }

    var hasItems: Bool {
        itemsInteractor.hasItems
    }

    func hasItems(for contentType: ItemContentType) -> Bool {
        !itemsInteractor.listItems(searchPhrase: nil, tagId: nil, vaultId: nil, contentTypes: [contentType], protectionLevel: nil, sortBy: .az, trashed: .no).isEmpty
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
    
    func loadList(contentType: ItemContentType?, tag: ItemTagData?, protectionLevel: ItemProtectionLevel?) -> [ItemData] {
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
            protectionLevel: protectionLevel,
            sortBy: currentSortType,
            trashed: .no
        )
    }
    
    func loadList(forServiceIdentifiers serviceIdentifiers: [String], contentType: ItemContentType?, tag: ItemTagData?, protectionLevel: ItemProtectionLevel?) -> (suggested: [ItemData], rest: [ItemData]) {
        let contentTypes: [ItemContentType]? = {
            if let contentType {
                return [contentType]
            } else {
                return nil
            }
        }()

        let allPasswords = itemsInteractor.listItems(searchPhrase: searchPhrase, tagId: tag?.tagID, vaultId: nil, contentTypes: contentTypes, protectionLevel: protectionLevel, sortBy: currentSortType, trashed: .no)

        guard serviceIdentifiers.isEmpty == false else {
            return ([], allPasswords)
        }

        var suggested: [ItemData] = []
        var rest: [ItemData] = []
        var processedItemIDs: Set<ItemID> = []

        for element in allPasswords where Config.autoFillExcludeProtectionLevels.contains(element.protectionLevel) == false {
            guard processedItemIDs.contains(element.id) == false else { continue }

            if case let .login(loginItem) = element {
                var isSuggested = false

                if let uris = loginItem.content.uris {
                    for autofillService in serviceIdentifiers {
                        let isMatch = uris.contains(where: { uri in
                            uriInteractor.isMatch(uri.uri, to: autofillService, rule: uri.match)
                        })
                        if isMatch {
                            isSuggested = true
                            break
                        }
                    }
                }

                if isSuggested {
                    suggested.append(element)
                } else {
                    rest.append(element)
                }
                processedItemIDs.insert(element.id)
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

    func copyWiFiSSID(_ itemID: ItemID) -> Bool {
        guard let wifiItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asWiFi,
              let ssid = wifiItem.content.ssid else {
            return false
        }
        systemInteractor.copyToClipboard(ssid)
        return true
    }

    func copyWiFiPassword(_ itemID: ItemID) -> Bool {
        guard let wifiItem = itemsInteractor.getItem(for: itemID, checkInTrash: false)?.asWiFi,
              let password = wifiItem.content.password,
              let decryptedPassword = itemsInteractor.decrypt(password, isSecureField: true, protectionLevel: wifiItem.protectionLevel) else {
            return false
        }
        systemInteractor.copyToClipboard(decryptedPassword)
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

    func getTag(for tagID: ItemTagID) -> ItemTagData? {
        tagInteractor.getTag(for: tagID)
    }

    func countItemsForTag(_ tagID: ItemTagID) -> Int {
        itemsInteractor.getItemCountForTag(tagID: tagID, contentType: nil)
    }

    func countItemsForProtectionLevel(_ protectionLevel: ItemProtectionLevel) -> Int {
        itemsInteractor.listItems(
            searchPhrase: nil,
            tagId: nil,
            vaultId: nil,
            contentTypes: .allKnownTypes,
            protectionLevel: protectionLevel,
            sortBy: currentSortType,
            trashed: .no
        ).count
    }

    func updateProtectionLevel(_ protectionLevel: ItemProtectionLevel, for itemIDs: [ItemID]) throws(ItemsInteractorSaveError) {
        guard itemIDs.isEmpty == false else { return }
        let updatedItems = try itemsInteractor.updateItems(
            itemIDs,
            to: protectionLevel
        )
        let loginItems = updatedItems.compactMap(\.asLoginItem)
        if loginItems.isEmpty == false {
            Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                try await autoFillCredentialsInteractor.replaceSuggestions(
                    for: loginItems
                )
            }
        }
        syncChangeTriggerInteractor.trigger()
    }

    func applyTagChanges(to itemIDs: [ItemID], tagsToAdd: Set<ItemTagID>, tagsToRemove: Set<ItemTagID>) throws {
        guard itemIDs.isEmpty == false else { return }
        guard tagsToAdd.isEmpty == false || tagsToRemove.isEmpty == false else { return }

        tagInteractor.applyTagChangesToItems(
            itemIDs,
            tagsToAdd: tagsToAdd,
            tagsToRemove: tagsToRemove
        )
        tagInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
}
