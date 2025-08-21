// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol PasswordsModuleInteracting: AnyObject {
    var currentPlanItemsLimit: Int { get }
    var canAddPassword: Bool { get }
    var selectAction: PasswordListAction { get }
    
    var currentSortType: SortType { get }
    func setSortType(_ sortType: SortType)
    
    func loadList() -> [PasswordData]
    func loadList(forServiceIdentifiers serviceURIs: [String]) -> (suggested: [PasswordData], rest: [PasswordData])

    var isSearching: Bool { get }
    func setSearchPhrase(_ searchPhrase: String?)
    
    func moveToTrash(_ passwordID: PasswordID)
    func copyUsername(_ passwordID: PasswordID) -> Bool
    func copyPassword(_ passwordID: PasswordID) -> Bool
    
    func cachedImage(from url: URL) -> Data?
    func fetchIconImage(from url: URL) async throws -> Data
    
    func normalizedURL(for uri: String) -> URL?
    func listAllTags() -> [ItemTagData]
    func countPasswordsForTag(_ tagID: ItemTagID) -> Int
}

final class PasswordsModuleInteractor {
    private let passwordInteractor: PasswordInteracting
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
        passwordInteractor: PasswordInteracting,
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
        self.passwordInteractor = passwordInteractor
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
    
    var canAddPassword: Bool {
        guard let limit = paymentStatusInteractor.entitlements.itemsLimit else {
            return true
        }
        return passwordInteractor.passwordsCount < limit
    }
    
    var currentPlanItemsLimit: Int {
        paymentStatusInteractor.entitlements.itemsLimit ?? Int.max
    }
    
    var selectAction: PasswordListAction {
        configInteractor.defaultPassswordListAction
    }
    
    func loadList() -> [PasswordData] {
        passwordInteractor.listPasswords(
            searchPhrase: searchPhrase,
            sortBy: currentSortType,
            trashed: .no
        )
    }
    
    func loadList(forServiceIdentifiers serviceIdentifiers: [String]) -> (suggested: [PasswordData], rest: [PasswordData]) {
        let allPasswords = passwordInteractor.listPasswords(searchPhrase: nil, sortBy: currentSortType, trashed: .no)
        
        guard serviceIdentifiers.isEmpty == false else {
            return ([], allPasswords)
        }
        
        var suggested: [PasswordData] = []
        var rest: [PasswordData] = []
        
        for autofillService in serviceIdentifiers {
            for element in allPasswords where Config.autoFillExcludeProtectionLevels.contains(element.protectionLevel) == false {
                if let uris = element.uris {
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
    
    func moveToTrash(_ passwordID: PasswordID) {
        Log("PasswordsModuleInteractor: Move to trash: \(passwordID)", module: .moduleInteractor)
        let deletedPassword = passwordInteractor.getPassword(for: passwordID, checkInTrash: false)
        passwordInteractor.markAsTrashed(for: passwordID)
        passwordInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
        if let deletedPassword {
            Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                try await autoFillCredentialsInteractor.removeSuggestions(for: deletedPassword)
            }
        }
    }
    
    func copyUsername(_ passwordID: PasswordID) -> Bool {
        guard let password = passwordInteractor.getPassword(for: passwordID, checkInTrash: false),
              let username = password.username
        else {
            return false
        }
        systemInteractor.copyToClipboard(username)
        return true
    }
    
    func copyPassword(_ passwordID: PasswordID) -> Bool {
        let passwordResult = passwordInteractor.getPasswordEncryptedContents(for: passwordID, checkInTrash: false)

        switch passwordResult {
        case .success(let password):
            if let password {
                systemInteractor.copyToClipboard(password)
                return true
            } else {
                return false
            }
        case .failure:
            return false
        }
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
    }
    
    func countPasswordsForTag(_ tagID: ItemTagID) -> Int {
        passwordInteractor.getItemCountForTag(tagID: tagID)
    }
}
