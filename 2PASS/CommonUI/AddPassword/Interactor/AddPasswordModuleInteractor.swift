// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

public typealias SavePasswordResult = Result<SavePasswordSuccess, SavePasswordError>

public enum SavePasswordSuccess {
    case saved(ItemID)
    case deleted(ItemID)
    
    public var itemID: ItemID {
        switch self {
        case .saved(let itemID):
            return itemID
        case .deleted(let itemID):
            return itemID
        }
    }
}

public enum SavePasswordError: Error {
    case userCancelled
    case interactorError(ItemsInteractorSaveError)
}

enum AddPasswordModuleInteractorCheckState {
    case noChange
    case deleted
    case edited
}

protocol AddPasswordModuleInteracting: AnyObject {
    var hasPasswords: Bool { get }
    var changeRequest: PasswordDataChangeRequest? { get }
    
    var currentDefaultProtectionLevel: ItemProtectionLevel { get }
    
    func getEditPassword() -> LoginItemData?
    func getDecryptedPassword() -> String?
    func getTags(for tagIds: [ItemTagID]) -> [ItemTagData]
    
    func savePassword(
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> SavePasswordResult
    
    func mostUsedUsernames() -> [String]
    func normalizeURLString(_ str: String) -> String?
    func extractDomain(from urlString: String) -> String?
    func generatePassword() -> String
    func fetchIconImage(from url: URL) async throws -> Data
    func checkCurrentPasswordState() -> AddPasswordModuleInteractorCheckState
    func moveToTrash() -> ItemID?
}

final class AddPasswordModuleInteractor {
    public let changeRequest: PasswordDataChangeRequest?
    
    private let itemsInteractor: ItemsInteracting
    private let configInteractor: ConfigInteracting
    private let uriInteractor: URIInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    private let passwordGeneratorInteractor: PasswordGeneratorInteracting
    private let fileIconInteractor: FileIconInteracting
    private let currentDateInteractor: CurrentDateInteracting
    private let passwordListInteractor: PasswordListInteracting
    private let tagInteractor: TagInteracting
    private let editItemID: ItemID?
    
    private var modificationDate: Date?
    
    init(
        itemsInteractor: ItemsInteracting,
        configInteractor: ConfigInteracting,
        uriInteractor: URIInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting,
        autoFillCredentialsInteractor: AutoFillCredentialsInteracting,
        passwordGeneratorInteractor: PasswordGeneratorInteracting,
        fileIconInteractor: FileIconInteracting,
        currentDateInteractor: CurrentDateInteracting,
        passwordListInteractor: PasswordListInteracting,
        tagInteractor: TagInteracting,
        editItemID: ItemID?,
        changeRequest: PasswordDataChangeRequest? = nil
    ) {
        self.itemsInteractor = itemsInteractor
        self.configInteractor = configInteractor
        self.uriInteractor = uriInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
        self.passwordGeneratorInteractor = passwordGeneratorInteractor
        self.fileIconInteractor = fileIconInteractor
        self.currentDateInteractor = currentDateInteractor
        self.passwordListInteractor = passwordListInteractor
        self.tagInteractor = tagInteractor
        self.editItemID = editItemID
        self.changeRequest = changeRequest
    }
}

extension AddPasswordModuleInteractor: AddPasswordModuleInteracting {
        
    var hasPasswords: Bool {
        itemsInteractor.hasItems
    }
    
    var currentDefaultProtectionLevel: ItemProtectionLevel {
        configInteractor.currentDefaultProtectionLevel
    }
    
    func getEditPassword() -> LoginItemData? {
        guard let editItemID else {
            return nil
        }
        let pass = itemsInteractor.getItem(for: editItemID, checkInTrash: false)?.asLoginItem
        modificationDate = pass?.modificationDate
        return pass
    }
    
    func getDecryptedPassword() -> String? {
        guard let editItemID else {
            return nil
        }
        return itemsInteractor.getPasswordEncryptedContents(for: editItemID, checkInTrash: false)
            .unpack() ?? nil
    }
    
    func getTags(for tagIds: [ItemTagID]) -> [ItemTagData] {
        tagInteractor.getTags(by: tagIds).sorted(by: { $0.name < $1.name })
    }
    
    func savePassword(
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> SavePasswordResult {
        let date = currentDateInteractor.currentDate
        if let current = getEditPassword() {
            do {
                try itemsInteractor.updateLogin(
                    id: current.id,
                    metadata: .init(
                        creationDate: current.creationDate,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds ?? current.tagIds
                    ),
                    name: name,
                    username: username,
                    password: password,
                    notes: notes,
                    iconType: iconType,
                    uris: uris
                )
                
                Log("AddPasswordModuleInteractor - success while updating password. Saving storage")
                itemsInteractor.saveStorage()
                syncChangeTriggerInteractor.trigger()
                
                Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                    try await autoFillCredentialsInteractor.replaceSuggestions(
                        from: current,
                        itemID: current.id,
                        username: username,
                        uris: uris,
                        protectionLevel: protectionLevel
                    )
                }
                
                return .success(.saved(current.id))
                
            } catch {
                return .failure(.interactorError(error))
            }
        } else {
            let itemID = UUID()
            do {
                try itemsInteractor.createLogin(
                    id: itemID,
                    metadata: .init(
                        creationDate: date,
                        modificationDate: date,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: tagIds
                    ),
                    name: name,
                    username: username,
                    password: password,
                    notes: notes,
                    iconType: iconType,
                    uris: uris
                )
                
                Log("AddPasswordModuleInteractor - success while adding password. Saving storage")
                
                itemsInteractor.saveStorage()
                syncChangeTriggerInteractor.trigger()
            
                Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                    try await autoFillCredentialsInteractor.addSuggestions(
                        itemID: itemID,
                        username: username,
                        uris: uris,
                        protectionLevel: protectionLevel
                    )
                }
                
                return .success(.saved(itemID))
                
            } catch {
                return .failure(.interactorError(error))
            }
        }
    }
    
    func mostUsedUsernames() -> [String] {
        passwordListInteractor.mostUsedUsernames()
    }
    
    func normalizeURLString(_ str: String) -> String? {
        uriInteractor.normalize(str)
    }
    
    func extractDomain(from urlString: String) -> String? {
        uriInteractor.extractDomain(from: urlString)
    }
    
    func generatePassword() -> String {
        let config = configInteractor.passwordGeneratorConfig ?? .init(length: passwordGeneratorInteractor.prefersPasswordLength, hasDigits: true, hasUppercase: true, hasSpecial: true)
        return passwordGeneratorInteractor.generatePassword(using: config)
    }
    
    func fetchIconImage(from url: URL) async throws -> Data {
        try await fileIconInteractor.fetchImage(from: url)
    }
    
    func checkCurrentPasswordState() -> AddPasswordModuleInteractorCheckState {
        guard let editItemID, let modificationDate else { return .noChange }
        guard let pass = itemsInteractor.getItem(for: editItemID, checkInTrash: false) else {
            return .deleted
        }
        if pass.modificationDate.isAfter(modificationDate) {
            return .edited
        }
        return .noChange
    }
    
    func moveToTrash() -> ItemID? {
        guard let editItemID else {
            return nil
        }
        itemsInteractor.markAsTrashed(for: editItemID)
        itemsInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
        return editItemID
    }
}
