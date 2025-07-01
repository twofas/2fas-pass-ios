// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public enum PasswordInteractorSaveError: Error {
    case encryptionError
    case noVault
}

public enum PasswordInteractorReencryptError: Error {
    case encryptionError
    case noVault
}


public enum PasswordInteractorGetError: Error {
    case noPassword
    case decryptionError
    case noEntity
}

public protocol PasswordInteracting: AnyObject {
    var hasPasswords: Bool { get }
    var passwordsCount: Int { get }
    
    func createPassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError>
    
    func updatePassword(
        for passwordID: PasswordID,
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError>
    
    func createPasswordWithEncryptedPassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        encryptedPassword: Data?,
        notes: String?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError>
    
    func updatePasswordWithEncryptedPassword(
        for passwordID: PasswordID,
        name: String?,
        username: String?,
        encryptedPassword: Data?,
        notes: String?,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError>
    
    func saveStorage()
    
    func listPasswords(
        searchPhrase: String?,
        sortBy: SortType,
        trashed: PasswordListOptions.TrashOptions
    ) -> [PasswordData]
    func listTrashedPasswords() -> [PasswordData]
    func listAllPasswords() -> [PasswordData]
    
    func getPasswordEncryptedContents(
        for passwordID: PasswordID,
        checkInTrash: Bool
    ) -> Result<String?, PasswordInteractorGetError>
    func getPassword(for passwordID: PasswordID, checkInTrash: Bool) -> PasswordData?
    func getEncryptedPasswordEntity(passwordID: PasswordID) -> PasswordEncryptedData?
    
    func deletePassword(for passwordID: PasswordID)
    func markAsTrashed(for passwordID: PasswordID)
    func externalMarkAsTrashed(for passwordID: PasswordID)
    func markAsNotTrashed(for passwordID: PasswordID)
    
    var currentSortType: SortType { get }
    func setSortType(_ sortType: SortType)
    
    func mostUsedUsernames() -> [String]
    
    @discardableResult func loadTrustedKey() -> Bool
    
    func encrypt(_ string: String, isPassword: Bool, protectionLevel: PasswordProtectionLevel) -> Data?
    func encryptData(_ data: Data, isPassword: Bool, protectionLevel: PasswordProtectionLevel) -> Data?
    func decrypt(_ data: Data, isPassword: Bool, protectionLevel: PasswordProtectionLevel) -> String?
    
    // MARK: - Change Password
    func getCompleteDecryptedList() -> ([PasswordData], [ItemTagData])
    func reencryptDecryptedList(
        _ list: [PasswordData],
        tags: [ItemTagData],
        completion: @escaping (Result<Void, PasswordInteractorReencryptError>) -> Void
    )
    
    // MARK: - Deleted Items
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date)
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date)
    func listDeletedItems() -> [DeletedItemData]
    func deleteDeletedItem(id: DeletedItemID)
    
    // MARK: - Tags
    @discardableResult
    func createTag(name: String, color: String) -> Bool

    @discardableResult
    func createTag(data: ItemTagData) -> Bool
    
    @discardableResult
    func updateTag(data: ItemTagData) -> Bool
    
    func deleteTag(tagID: ItemTagID)
    func externalDeleteTag(tagID: ItemTagID)
    
    func listAllTags() -> [ItemTagData]
}

final class PasswordInteractor {
    private let mostUsedUsernamesCount = 5
    
    private let mainRepository: MainRepository
    private let protectionInteractor: ProtectionInteracting
    private let uriInteractor: URIInteracting
    
    init(
        mainRepository: MainRepository,
        protectionInteractor: ProtectionInteracting,
        uriInteractor: URIInteracting
    ) {
        self.mainRepository = mainRepository
        self.protectionInteractor = protectionInteractor
        self.uriInteractor = uriInteractor
    }
}

extension PasswordInteractor: PasswordInteracting {
    
    var hasPasswords: Bool { !mainRepository.listPasswords(options: .allNotTrashed).isEmpty }
    
    var passwordsCount: Int {
        mainRepository.listPasswords(options: .allNotTrashed).count
    }
    
    func createPassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError> {
        var encryptedPassword: Data?
        if let password = password?.trim(), !password.isEmpty {
            guard let encrypted = encrypt(password, isPassword: true, protectionLevel: protectionLevel) else {
                Log(
                    "Password interactor: Create password. Can't encrypt password",
                    module: .interactor,
                    severity: .error
                )
                return .failure(.encryptionError)
            }
            encryptedPassword = encrypted
        }
        
        return createPasswordWithEncryptedPassword(
            passwordID: passwordID,
            name: name,
            username: username,
            encryptedPassword: encryptedPassword,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            tagIds: tagIds
        )
    }
    
    func updatePassword(
        for passwordID: PasswordID,
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError> {
        var encryptedPassword: Data?
        if let password = password?.trim(), !password.isEmpty {
            guard let encrypted = encrypt(password, isPassword: true, protectionLevel: protectionLevel) else {
                Log(
                    "Password interactor: Update password. Can't encrypt password",
                    module: .interactor,
                    severity: .error
                )
                return .failure(.encryptionError)
            }
            encryptedPassword = encrypted
        }
        
        return updatePasswordWithEncryptedPassword(
            for: passwordID,
            name: name,
            username: username,
            encryptedPassword: encryptedPassword,
            notes: notes,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            tagIds: tagIds
        )
    }
    
    func createPasswordWithEncryptedPassword(
        passwordID: PasswordID,
        name: String?,
        username: String?,
        encryptedPassword: Data?,
        notes: String?,
        creationDate: Date,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError> {
        var encryptedName: Data?
        let name = name.nilIfEmpty
        if let name {
            guard let encrypted = encrypt(name, isPassword: false, protectionLevel: protectionLevel) else {
                Log("Password interactor: Create password. Can't encrypt name", module: .interactor, severity: .error)
                return .failure(.encryptionError)
            }
            encryptedName = encrypted
        }
        
        var encryptedUsername: Data?
        let username = username.nilIfEmpty
        if let username {
            guard let encrypted = encrypt(username, isPassword: false, protectionLevel: protectionLevel) else {
                Log(
                    "Password interactor: Create password. Can't encrypt username",
                    module: .interactor,
                    severity: .error
                )
                return .failure(.encryptionError)
            }
            encryptedUsername = encrypted
        }
        
        guard let encryptedIconType = createEncryptedIconType(
            iconType: iconType,
            protectionLevel: protectionLevel
        ) else {
            Log("Password interactor: Create password. Can't encrypt icon type", module: .interactor, severity: .error)
            return .failure(.encryptionError)
        }
        
        var encryptedURIs: PasswordEncryptedURIs?
        if let uris, !uris.isEmpty {
            guard let encrypted = createEncryptedURIs(from: uris, protectionLevel: protectionLevel) else {
                Log("Password interactor: Create password. Can't encrypt uris", module: .interactor, severity: .error)
                return .failure(.encryptionError)
            }
            encryptedURIs = encrypted
        }
        
        var encryptedNotes: Data?
        if let notes {
            guard let encrypted = encrypt(notes, isPassword: false, protectionLevel: protectionLevel) else {
                Log(
                    "Password interactor: Create password. Can't encrypt notes",
                    module: .interactor,
                    severity: .error
                )
                return .failure(.encryptionError)
            }
            encryptedNotes = encrypted
        }
        
        guard let selectedVault = mainRepository.selectedVault else {
            Log("Password interactor: Create password. No vault", module: .interactor, severity: .error)
            return .failure(.noVault)
        }
        
        mainRepository.createPassword(
            passwordID: passwordID,
            name: name,
            username: username,
            password: encryptedPassword,
            notes: notes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            tagIds: tagIds
        )
        
        mainRepository.createEncryptedPassword(
            passwordID: passwordID,
            name: encryptedName,
            username: encryptedUsername,
            password: encryptedPassword,
            notes: encryptedNotes,
            creationDate: creationDate,
            modificationDate: modificationDate,
            iconType: encryptedIconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            vaultID: selectedVault.vaultID,
            uris: encryptedURIs,
            tagIds: tagIds
        )
        
        return .success(())
    }
    
    func updatePasswordWithEncryptedPassword(
        for passwordID: PasswordID,
        name: String?,
        username: String?,
        encryptedPassword: Data?,
        notes: String?,
        modificationDate: Date,
        iconType: PasswordIconType,
        trashedStatus: PasswordTrashedStatus,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError> {
        guard let (encryptedName,
                   encryptedUsername,
                   encryptedNotes,
                   encryptedIconType,
                   encryptedURIs) = encrypt(
                    name: name,
                    username: username,
                    notes: notes,
                    iconType: iconType,
                    protectionLevel: protectionLevel,
                    uris: uris
                   ) else {
            return .failure(.encryptionError)
        }
        
        guard let selectedVault = mainRepository.selectedVault else {
            Log("Password interactor: Update password. No vault", module: .interactor, severity: .error)
            return .failure(.noVault)
        }
        
        mainRepository.updatePassword(
            passwordID: passwordID,
            name: name,
            username: username,
            password: encryptedPassword,
            notes: notes,
            modificationDate: modificationDate,
            iconType: iconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            uris: uris,
            tagIds: tagIds
        )
        
        mainRepository.updateEncryptedPassword(
            passwordID: passwordID,
            name: encryptedName,
            username: encryptedUsername,
            password: encryptedPassword,
            notes: encryptedNotes,
            modificationDate: modificationDate,
            iconType: encryptedIconType,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            vaultID: selectedVault.vaultID,
            uris: encryptedURIs,
            tagIds: tagIds
        )

        return .success(())
    }
    
    func saveStorage() {
        mainRepository.saveStorage()
        mainRepository.saveEncryptedStorage()
    }
    
    func listPasswords(
        searchPhrase: String?,
        sortBy: SortType = .newestFirst,
        trashed: PasswordListOptions.TrashOptions = .no
    ) -> [PasswordData] {
        let searchPhrase: String? = {
            if let searchPhrase {
                if searchPhrase.isEmpty {
                    return nil
                }
                return searchPhrase
            }
            return nil
        }()
        return mainRepository.listPasswords(options: .filterByPhrase(searchPhrase, sortBy: sortBy, trashed: trashed))
    }
    
    func listTrashedPasswords() -> [PasswordData] {
        mainRepository.listTrashedPasswords()
    }
    
    func listAllPasswords() -> [PasswordData] {
        listPasswords(searchPhrase: nil, sortBy: .newestFirst, trashed: .all)
    }
    
    func getPasswordEncryptedContents(for passwordID: PasswordID, checkInTrash: Bool = false) -> Result<String?, PasswordInteractorGetError> {
        guard let entity = mainRepository.getPasswordEntity(passwordID: passwordID, checkInTrash: checkInTrash) else {
            return .failure(.noEntity)
        }
        guard let password = entity.password else {
            return .failure(.noPassword)
        }
        guard let decryptedPassword = decrypt(
            password,
            isPassword: true,
            protectionLevel: entity.protectionLevel
        ) else {
            return .failure(.decryptionError)
        }
        return .success(decryptedPassword)
    }
    
    func getPassword(for passwordID: PasswordID, checkInTrash: Bool) -> PasswordData? {
        mainRepository.getPasswordEntity(passwordID: passwordID, checkInTrash: checkInTrash)
    }
    
    func getEncryptedPasswordEntity(passwordID: PasswordID) -> PasswordEncryptedData? {
        mainRepository.getEncryptedPasswordEntity(passwordID: passwordID)
    }
    
    func deletePassword(for passwordID: PasswordID) {
        Log(
            "PasswordInteractor: Deleting password for passwordID: \(passwordID)",
            module: .interactor,
            obfuscate: true
        )
        mainRepository.deletePassword(passwordID: passwordID)
        mainRepository.deleteEncryptedPassword(passwordID: passwordID)
    }
    
    func markAsTrashed(for passwordID: PasswordID) {
        let date = mainRepository.currentDate
        
        Log(
            "PasswordInteractor: Marking as trashed for passwordID: \(passwordID)",
            module: .interactor,
            obfuscate: true
        )
        guard let entity = getPassword(for: passwordID, checkInTrash: false),
              let encryptedEntity = mainRepository.getEncryptedPasswordEntity(passwordID: passwordID)
        else {
            return
        }
        
        markAsTrashed(entity: entity, encryptedEntity: encryptedEntity, date: date)
        mainRepository.createDeletedItem(id: passwordID, kind: .login, deletedAt: date, in: encryptedEntity.vaultID)
    }
    
    func externalMarkAsTrashed(for passwordID: PasswordID) {
        Log(
            "PasswordInteractor: External marking as trashed for passwordID: \(passwordID)",
            module: .interactor,
            obfuscate: true
        )
        guard let entity = getPassword(for: passwordID, checkInTrash: false),
              let encryptedEntity = mainRepository.getEncryptedPasswordEntity(passwordID: passwordID)
        else {
            return
        }
        
        let date = mainRepository.currentDate
        markAsTrashed(entity: entity, encryptedEntity: encryptedEntity, date: date)
    }
    
    func markAsNotTrashed(for passwordID: PasswordID) {
        Log(
            "PasswordInteractor: Marking as not trashed for passwordID: \(passwordID)",
            module: .interactor,
            obfuscate: true
        )
        guard let entity = getPassword(for: passwordID, checkInTrash: true),
              let encryptedEntity = mainRepository.getEncryptedPasswordEntity(passwordID: passwordID)
        else {
            return
        }
        let date = mainRepository.currentDate
        mainRepository.updatePassword(
            passwordID: passwordID,
            name: entity.name,
            username: entity.username,
            password: entity.password,
            notes: entity.notes,
            modificationDate: date,
            iconType: entity.iconType,
            trashedStatus: .no,
            protectionLevel: entity.protectionLevel,
            uris: entity.uris,
            tagIds: entity.tagIds
        )
        mainRepository.updateEncryptedPassword(
            passwordID: passwordID,
            name: encryptedEntity.name,
            username: encryptedEntity.username,
            password: encryptedEntity.password,
            notes: encryptedEntity.notes,
            modificationDate: date,
            iconType: encryptedEntity.iconType,
            trashedStatus: .no,
            protectionLevel: encryptedEntity.protectionLevel,
            vaultID: encryptedEntity.vaultID,
            uris: encryptedEntity.uris,
            tagIds: encryptedEntity.tagIds
        )
        mainRepository.deleteDeletedItem(id: passwordID)
    }
    
    func createTag(data: ItemTagData) -> Bool {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal),
              let nameData = data.name.data(using: .utf8),
              let nameEnc = mainRepository.encrypt(nameData, key: key) else {
            return false
        }
        // TODO: Add creation in in-memory storage
        mainRepository.createEncryptedTag(
            ItemTagEncryptedData(
                tagID: data.id,
                vaultID: data.vaultID,
                name: nameEnc,
                color: data.color?.hexString,
                position: data.position,
                modificationDate: data.modificationDate
            )
        )
        return true
    }
    
    func createTag(name: String, color: String) -> Bool {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("PasswordInteractor - error while getting vaultID for create tag", module: .interactor, severity: .error)
            return false
        }
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal),
              let nameData = name.data(using: .utf8),
              let nameEnc = mainRepository.encrypt(nameData, key: key) else {
            return false
        }
        // TODO: Fetch from in-memory storage

        let lastPosition = mainRepository.listEncryptedTags(in: vaultID).count
        // TODO: Add creation in in-memory storage

        mainRepository.createEncryptedTag(
            ItemTagEncryptedData(
                tagID: ItemTagID(),
                vaultID: vaultID,
                name: nameEnc,
                color: color,
                position: lastPosition,
                modificationDate: mainRepository.currentDate
            )
        )
        return true
    }
    
    @discardableResult
    func updateTag(data: ItemTagData) -> Bool {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal),
              let nameData = data.name.data(using: .utf8),
              let nameEnc = mainRepository.encrypt(nameData, key: key) else {
            return false
        }
        // TODO: Add creation in in-memory storage
        mainRepository.updateEncryptedTag(
            ItemTagEncryptedData(
                tagID: data.id,
                vaultID: data.vaultID,
                name: nameEnc,
                color: data.color?.hexString,
                position: data.position,
                modificationDate: data.modificationDate
            )
        )
        return true
    }
    
    func deleteTag(tagID: ItemTagID) {
        mainRepository.deleteTag(tagID: tagID)
        mainRepository.deleteEncryptedTag(tagID: tagID)

        createDeletedItem(id: tagID, kind: .tag, deletedAt: mainRepository.currentDate)
    }
    
    func externalDeleteTag(tagID: ItemTagID) {
        mainRepository.deleteEncryptedTag(tagID: tagID)
    }
    
    func listAllTags() -> [ItemTagData] {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("PasswordInteractor - error while getting vaultID for list tags", module: .interactor, severity: .error)
            return []
        }
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: .normal) else {
            return []
        }
        return mainRepository.listEncryptedTags(in: vaultID)
            .compactMap { tag in
                guard let nameData = mainRepository.decrypt(tag.name, key: key), let name = String(data: nameData, encoding: .utf8) else {
                    return nil
                }
                return ItemTagData(
                    tagID: tag.tagID,
                    vaultID: vaultID,
                    name: name,
                    color: UIColor(hexString: tag.color),
                    position: tag.position,
                    modificationDate: tag.modificationDate
                )
            }
    }
    
    var currentSortType: SortType {
        mainRepository.sortType ?? .az
    }
    
    func setSortType(_ sortType: SortType) {
        Log("PasswordInteractor: setting sort type to: \(sortType)", module: .interactor)
        mainRepository.setSortType(sortType)
    }
    
    func mostUsedUsernames() -> [String] {
        var aggregate: [String: Int] = [:]
        for name in mainRepository.listUsernames() {
            guard !name.isEmpty else { continue }
            var count: Int = aggregate[name] ?? 0
            count += 1
            aggregate[name] = count
        }
        return aggregate.sorted(by: { $0.value >= $1.value })
            .prefix(5)
            .map({ $0.key })
    }
    
    func encrypt(_ string: String, isPassword: Bool, protectionLevel: PasswordProtectionLevel) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        return encryptData(data, isPassword: isPassword, protectionLevel: protectionLevel)
    }
    
    func encryptData(_ data: Data, isPassword: Bool, protectionLevel: PasswordProtectionLevel) -> Data? {
        guard let key = mainRepository.getKey(isPassword: isPassword, protectionLevel: protectionLevel) else {
            return nil
        }
        return mainRepository.encrypt(data, key: key)
    }
    
    func decrypt(_ data: Data, isPassword: Bool, protectionLevel: PasswordProtectionLevel) -> String? {
        guard let key = mainRepository.getKey(isPassword: isPassword, protectionLevel: protectionLevel),
              let decryptedData = mainRepository.decrypt(data, key: key) else {
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }
    
    // MARK: - Change Password
    
    func getCompleteDecryptedList() -> ([PasswordData], [ItemTagData])  {
        (
            listPasswords(searchPhrase: nil, trashed: .all)
                .compactMap({ entity in
                    var newEntity = entity
                    if let password = entity.password {
                        guard let decryptedPassword = decrypt(
                            password,
                            isPassword: true,
                            protectionLevel: entity.protectionLevel
                        ), let data = decryptedPassword.data(using: .utf8) else {
                            Log("PasswordInteractor: can't decrypt password for: \(entity.passwordID)", module: .interactor)
                            return nil
                        }
                        newEntity = .init(
                            passwordID: entity.passwordID,
                            name: entity.name,
                            username: entity.username,
                            password: data,
                            notes: entity.notes,
                            creationDate: entity.creationDate,
                            modificationDate: entity.modificationDate,
                            iconType: entity.iconType,
                            trashedStatus: entity.trashedStatus,
                            protectionLevel: entity.protectionLevel,
                            uris: entity.uris,
                            tagIds: entity.tagIds
                        )
                    }
                    return newEntity
                }),
            listAllTags()
        )
    }
    
    func reencryptDecryptedList(
        _ list: [PasswordData],
        tags: [ItemTagData],
        completion: @escaping (Result<Void, PasswordInteractorReencryptError>) -> Void
    ) {
        let date = mainRepository.currentDate
        Log("Password interactor - Reencrypting \(list.count) passwords", module: .interactor)
        guard let selectedVaultID = mainRepository.selectedVault?.vaultID else {
            Log("Password interactor: Update password. No vault", module: .interactor, severity: .error)
            completion(.failure(.noVault))
            return
        }
        
        enum DataFiller1: Equatable {
            case passwordData(PasswordData)
            case error
        }
        
        var passwordsEncryptedBuffer: [DataFiller1] = list.map({ .passwordData($0) })
        
        passwordsEncryptedBuffer.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                let current = buffer[i]
                switch current {
                case .passwordData(let passwordData):
                    if let passData = passwordData.password,
                       let passString = String(data: passData, encoding: .utf8) {
                        if let encrypted = encrypt(passString, isPassword: true, protectionLevel: passwordData.protectionLevel) {
                            buffer[i] = .passwordData(passwordData.updatePassword(encrypted, using: date))
                        } else {
                            buffer[i] = .error
                        }
                    }
                default: break
                }
            }
        }
        
        Log("Password interactor - Password field encrypted", module: .interactor)
        
        let passwordsEncrypted = passwordsEncryptedBuffer.compactMap {
            switch $0 {
            case .passwordData(let passData): passData
            case .error: nil
            }
        }
        
        guard passwordsEncrypted.count == passwordsEncryptedBuffer.count else {
            completion(.failure(.encryptionError))
            return
        }
        
        enum DataFiller2: Equatable {
            case empty
            case passwordData(PasswordEncryptedData)
            case error
        }
        
        var fullyEncryptedBuffer: [DataFiller2] = [DataFiller2](repeating: .empty, count: passwordsEncrypted.count)
        
        fullyEncryptedBuffer.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                let current = passwordsEncrypted[i]
                
                if let (encryptedName,
                        encryptedUsername,
                        encryptedNotes,
                        encryptedIconType,
                        encryptedURIs) = encrypt(
                            name: current.name,
                            username: current.username,
                            notes: current.notes,
                            iconType: current.iconType,
                            protectionLevel: current.protectionLevel,
                            uris: current.uris
                        ) {
                    buffer[i] = .passwordData(.init(passwordID: current.passwordID, name: encryptedName, username: encryptedUsername, password: current.password, notes: encryptedNotes, creationDate: current.creationDate, modificationDate: current.modificationDate, iconType: encryptedIconType, trashedStatus: current.trashedStatus, protectionLevel: current.protectionLevel, vaultID: selectedVaultID, uris: encryptedURIs, tagIds: current.tagIds))
                } else {
                    buffer[i] = .error
                }
            }
        }
        
        
        let fullyEncrypted = fullyEncryptedBuffer.compactMap {
            switch $0 {
            case .passwordData(let passData): passData
            default: nil
            }
        }
        
        guard fullyEncrypted.count == fullyEncryptedBuffer.count else {
            completion(.failure(.encryptionError))
            return
        }
        
        Log("Password interactor - rest of the field encrypted", module: .interactor)
        
        mainRepository.passwordsBatchUpdate(passwordsEncrypted)
        Log("Password interactor - Password entries updated", module: .interactor)
        mainRepository.encryptedPasswordsBatchUpdate(fullyEncrypted)
        Log("Password interactor - Password encrypted entries updated", module: .interactor)
        
        for tag in tags {
            updateTag(data: tag)
        }
        
        saveStorage()
        
        completion(.success(()))
    }
    
    // MARK: - Deleted Items
    func createDeletedItem(id: ItemTagID, kind: DeletedItemData.Kind, deletedAt: Date) {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("PasswordInteractor - error while getting vaultID for Deleted Password creation", module: .interactor, severity: .error)
            return
        }
        mainRepository.createDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }
    
    func listDeletedItems() -> [DeletedItemData] {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("PasswordInteractor - error while getting vaultID for listing Deleted Password", module: .interactor, severity: .error)
            return []
        }
        return mainRepository.listDeletedItems(in: vaultID, limit: nil)
    }
    
    func deleteDeletedItem(id: PasswordID) {
        mainRepository.deleteDeletedItem(id: id)
    }
    
    func updateDeletedItem(id: PasswordID, kind: DeletedItemData.Kind, deletedAt: Date) {
        guard let vaultID = mainRepository.selectedVault?.vaultID else {
            Log("PasswordInteractor - error while getting vaultID for Deleted Password update", module: .interactor, severity: .error)
            return
        }
        mainRepository.updateDeletedItem(id: id, kind: kind, deletedAt: deletedAt, in: vaultID)
    }
    
    @discardableResult func loadTrustedKey() -> Bool {
        guard let trustedKey = mainRepository.trustedKeyFromVault else {
            Log("PasswordInteractor - error while loading trusted key", module: .interactor, severity: .error)
            return false
        }
        mainRepository.setTrustedKey(trustedKey)
        return true
    }
}

private extension PasswordInteractor {
    
    func markAsTrashed(entity: PasswordData, encryptedEntity: PasswordEncryptedData, date: Date) {
        mainRepository.updatePassword(
            passwordID: entity.passwordID,
            name: entity.name,
            username: entity.username,
            password: entity.password,
            notes: entity.notes,
            modificationDate: date,
            iconType: entity.iconType,
            trashedStatus: .yes(trashingDate: date),
            protectionLevel: entity.protectionLevel,
            uris: entity.uris,
            tagIds: entity.tagIds
        )
        mainRepository.updateEncryptedPassword(
            passwordID: entity.passwordID,
            name: encryptedEntity.name,
            username: encryptedEntity.username,
            password: encryptedEntity.password,
            notes: encryptedEntity.notes,
            modificationDate: date,
            iconType: encryptedEntity.iconType,
            trashedStatus: .yes(trashingDate: date),
            protectionLevel: encryptedEntity.protectionLevel,
            vaultID: encryptedEntity.vaultID,
            uris: encryptedEntity.uris,
            tagIds: encryptedEntity.tagIds
        )
    }
    
    func createEncryptedIconType(
        iconType: PasswordIconType,
        protectionLevel: PasswordProtectionLevel
    ) -> PasswordEncryptedIconType? {
        let eIconType = iconType.value
        var eIconDomain: Data?
        var eIconCustomURL: Data?
        var eLabelTitle: Data?
        var eLabelColor: UIColor?
        
        switch iconType {
        case .domainIcon(let domain):
            if let domain, let encrypted = encrypt(
                domain,
                isPassword: false,
                protectionLevel: protectionLevel
            ) {
                eIconDomain = encrypted
            } else {
                eIconDomain = nil
            }
        case .customIcon(let iconURI):
            guard let encrypted = encrypt(
                iconURI.absoluteString,
                isPassword: false,
                protectionLevel: protectionLevel
            ) else {
                return nil
            }
            eIconCustomURL = encrypted
        case .label(let labelTitle, let labelColor):
            guard let encrypted = encrypt(labelTitle, isPassword: false, protectionLevel: protectionLevel) else {
                return nil
            }
            eLabelTitle = encrypted
            eLabelColor = labelColor
        }
        return PasswordEncryptedIconType(
            iconType: eIconType,
            iconDomain: eIconDomain,
            iconCustomURL: eIconCustomURL,
            labelTitle: eLabelTitle,
            labelColor: eLabelColor
        )
    }
    
    func createEncryptedURIs(
        from urisList: [PasswordURI],
        protectionLevel: PasswordProtectionLevel
    ) -> PasswordEncryptedURIs? {
        let uris: Data
        let match: [PasswordURI.Match] = urisList.map({ $0.match })
        
        let urisUnpacked = urisList.map({ $0.uri })
        guard let urisJSON = try? mainRepository.jsonEncoder.encode(urisUnpacked) else {
            Log("PasswordInteractor - can't encode uris to JSON", module: .interactor, severity: .error)
            return nil
        }
        guard let encryptedURIs = encryptData(urisJSON, isPassword: false, protectionLevel: protectionLevel) else {
            Log("PasswordInteractor - error encrypting uris JSON", module: .interactor, severity: .error)
            return nil
        }
        uris = encryptedURIs
        
        return PasswordEncryptedURIs(
            uris: uris,
            match: match
        )
    }
    
    func encrypt(
        name: String?,
        username: String?,
        notes: String?,
        iconType: PasswordIconType,
        protectionLevel: PasswordProtectionLevel,
        uris: [PasswordURI]?
    ) -> (
        encryptedName: Data?,
        encryptedUsername: Data?,
        encryptedNotes: Data?,
        encryptedIconType: PasswordEncryptedIconType,
        encryptedURIs: PasswordEncryptedURIs?
    )? {
        var encryptedName: Data?
        let name = name.nilIfEmpty
        if let name {
            guard let encrypted = encrypt(name, isPassword: false, protectionLevel: protectionLevel) else {
                Log("Password interactor: Update password. Can't encrypt name", module: .interactor, severity: .error)
                return nil
            }
            encryptedName = encrypted
        }
        
        var encryptedUsername: Data?
        let username = username.nilIfEmpty
        if let username {
            guard let encrypted = encrypt(username, isPassword: false, protectionLevel: protectionLevel) else {
                Log(
                    "Password interactor: Update password. Can't encrypt username",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            encryptedUsername = encrypted
        }
        
        var encryptedNotes: Data?
        if let notes {
            guard let encrypted = encrypt(notes, isPassword: false, protectionLevel: protectionLevel) else {
                Log(
                    "Password interactor: Update password. Can't encrypt notes",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            encryptedNotes = encrypted
        }
        
        guard let encryptedIconType = createEncryptedIconType(
            iconType: iconType,
            protectionLevel: protectionLevel
        ) else {
            Log("Password interactor: Update password. Can't encrypt icon type", module: .interactor, severity: .error)
            return nil
        }
        
        var encryptedURIs: PasswordEncryptedURIs?
        if let uris, !uris.isEmpty {
            guard let encrypted = createEncryptedURIs(from: uris, protectionLevel: protectionLevel) else {
                Log("Password interactor: Update password. Can't encrypt uris", module: .interactor, severity: .error)
                return nil
            }
            encryptedURIs = encrypted
        }
        
        return (
            encryptedName: encryptedName,
            encryptedUsername: encryptedUsername,
            encryptedNotes: encryptedNotes,
            encryptedIconType: encryptedIconType,
            encryptedURIs: encryptedURIs
        )
    }
}
