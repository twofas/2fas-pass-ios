// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

public typealias SavePasswordResult = Result<PasswordID, SavePasswordError>

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
    
    var currentDefaultProtectionLevel: PasswordProtectionLevel { get }
    
    func getEditPassword() -> PasswordData?
    func getDecryptedPassword() -> String?
    
    func savePassword(
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?
    ) -> SavePasswordResult
    
    func mostUsedUsernames() -> [String]
    func normalizeURLString(_ str: String) -> String?
    func extractDomain(from urlString: String) -> String?
    func generatePassword() -> String
    func fetchIconImage(from url: URL) async throws -> Data
    func checkCurrentPasswordState() -> AddPasswordModuleInteractorCheckState
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
        self.editPasswordID = editPasswordID
        self.changeRequest = changeRequest
    }
}

extension AddPasswordModuleInteractor: AddPasswordModuleInteracting {
        
    var hasPasswords: Bool {
        passwordInteractor.hasPasswords
    }
    
    var currentDefaultProtectionLevel: PasswordProtectionLevel {
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
    
    func savePassword(
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?
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
                tagIds: current.tagIds
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
                
                return .success(current.passwordID)
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
                tagIds: nil
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
                
                return .success(passwordID)
            case .failure(let error): return .failure(.interactorError(error))
            }
        }
    }
    
    func mostUsedUsernames() -> [String] {
        passwordInteractor.mostUsedUsernames()
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
}
