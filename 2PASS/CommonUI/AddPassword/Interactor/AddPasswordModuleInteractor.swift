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
    case saved(PasswordID)
    case deleted(PasswordID)
    
    public var passwordID: PasswordID {
        switch self {
        case .saved(let passwordID):
            return passwordID
        case .deleted(let passwordID):
            return passwordID
        }
    }
}

public enum SavePasswordError: Error {
    case userCancelled
    case interactorError(PasswordInteractorSaveError)
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
    
    func getEditPassword() -> PasswordData?
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
    func moveToTrash() -> PasswordID?
}

final class AddPasswordModuleInteractor {
    public let changeRequest: PasswordDataChangeRequest?
    
    private let passwordInteractor: PasswordInteracting
    private let configInteractor: ConfigInteracting
    private let uriInteractor: URIInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let autoFillCredentialsInteractor: AutoFillCredentialsInteracting
    private let passwordGeneratorInteractor: PasswordGeneratorInteracting
    private let fileIconInteractor: FileIconInteracting
    private let currentDateInteractor: CurrentDateInteracting
    private let passwordListInteractor: PasswordListInteracting
    private let tagInteractor: TagInteracting
    private let editPasswordID: PasswordID?
    
    private var modificationDate: Date?
    
    init(
        passwordInteractor: PasswordInteracting,
        configInteractor: ConfigInteracting,
        uriInteractor: URIInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting,
        autoFillCredentialsInteractor: AutoFillCredentialsInteracting,
        passwordGeneratorInteractor: PasswordGeneratorInteracting,
        fileIconInteractor: FileIconInteracting,
        currentDateInteractor: CurrentDateInteracting,
        passwordListInteractor: PasswordListInteracting,
        tagInteractor: TagInteracting,
        editPasswordID: PasswordID?,
        changeRequest: PasswordDataChangeRequest? = nil
    ) {
        self.passwordInteractor = passwordInteractor
        self.configInteractor = configInteractor
        self.uriInteractor = uriInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.autoFillCredentialsInteractor = autoFillCredentialsInteractor
        self.passwordGeneratorInteractor = passwordGeneratorInteractor
        self.fileIconInteractor = fileIconInteractor
        self.currentDateInteractor = currentDateInteractor
        self.passwordListInteractor = passwordListInteractor
        self.tagInteractor = tagInteractor
        self.editPasswordID = editPasswordID
        self.changeRequest = changeRequest
    }
}

extension AddPasswordModuleInteractor: AddPasswordModuleInteracting {
        
    var hasPasswords: Bool {
        passwordInteractor.hasPasswords
    }
    
    var currentDefaultProtectionLevel: ItemProtectionLevel {
        configInteractor.currentDefaultProtectionLevel
    }
    
    func getEditPassword() -> PasswordData? {
        guard let editPasswordID else {
            return nil
        }
        let pass = passwordInteractor.getPassword(for: editPasswordID, checkInTrash: false)
        modificationDate = pass?.modificationDate
        return pass
    }
    
    func getDecryptedPassword() -> String? {
        guard let editPasswordID else {
            return nil
        }
        return passwordInteractor.getPasswordEncryptedContents(for: editPasswordID, checkInTrash: false)
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
            switch passwordInteractor.updatePassword(
                for: current.passwordID,
                name: name,
                username: username,
                password: password,
                notes: notes,
                modificationDate: date,
                iconType: iconType,
                trashedStatus: .no,
                protectionLevel: protectionLevel,
                uris: uris,
                tagIds: tagIds ?? current.tagIds
            ) {
            case .success:
                Log("AddPasswordModuleInteractor - success while updating password. Saving storage")
                passwordInteractor.saveStorage()
                syncChangeTriggerInteractor.trigger()
                
                Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                    try await autoFillCredentialsInteractor.replaceSuggestions(
                        from: current,
                        passwordID: current.passwordID,
                        username: username,
                        uris: uris,
                        protectionLevel: protectionLevel
                    )
                }
                
                return .success(.saved(current.passwordID))
            case .failure(let error): return .failure(.interactorError(error))
            }
        } else {
            let passwordID = UUID()
            switch passwordInteractor.createPassword(
                passwordID: passwordID,
                name: name,
                username: username,
                password: password,
                notes: notes,
                creationDate: date,
                modificationDate: date,
                iconType: iconType,
                trashedStatus: .no,
                protectionLevel: protectionLevel,
                uris: uris,
                tagIds: tagIds
            ) {
            case .success:
                Log("AddPasswordModuleInteractor - success while adding password. Saving storage")
                passwordInteractor.saveStorage()
                syncChangeTriggerInteractor.trigger()
            
                Task.detached(priority: .utility) { [autoFillCredentialsInteractor] in
                    try await autoFillCredentialsInteractor.addSuggestions(
                        passwordID: passwordID,
                        username: username,
                        uris: uris,
                        protectionLevel: protectionLevel
                    )
                }
                
                return .success(.saved(passwordID))
            case .failure(let error): return .failure(.interactorError(error))
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
        guard let editPasswordID, let modificationDate else { return .noChange }
        guard let pass = passwordInteractor.getPassword(for: editPasswordID, checkInTrash: false) else {
            return .deleted
        }
        if pass.modificationDate.isAfter(modificationDate) {
            return .edited
        }
        return .noChange
    }
    
    func moveToTrash() -> PasswordID? {
        guard let editPasswordID else {
            return nil
        }
        passwordInteractor.markAsTrashed(for: editPasswordID)
        passwordInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
        return editPasswordID
    }
}
