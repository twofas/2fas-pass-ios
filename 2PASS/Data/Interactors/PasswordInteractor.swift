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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
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
    func getEncryptedPasswordEntity(passwordID: PasswordID) -> ItemEncryptedData?
    
    func deletePassword(for passwordID: PasswordID)
    func markAsTrashed(for passwordID: PasswordID)
    func externalMarkAsTrashed(for passwordID: PasswordID)
    func markAsNotTrashed(for passwordID: PasswordID)
    
    @discardableResult func loadTrustedKey() -> Bool
    
    func encrypt(_ string: String, isPassword: Bool, protectionLevel: ItemProtectionLevel) -> Data?
    func encryptData(_ data: Data, isPassword: Bool, protectionLevel: ItemProtectionLevel) -> Data?
    func decrypt(_ data: Data, isPassword: Bool, protectionLevel: ItemProtectionLevel) -> String?
    func decryptContent<T>(_ result: T.Type, from data: Data, protectionLevel: ItemProtectionLevel) -> T? where T: Decodable

    // MARK: - Change Password
    func getCompleteDecryptedList() -> ([PasswordData], [ItemTagData])
    func reencryptDecryptedList(
        _ list: [PasswordData],
        tags: [ItemTagData],
        completion: @escaping (Result<Void, PasswordInteractorReencryptError>) -> Void
    )
}

final class PasswordInteractor {
    private let mostUsedUsernamesCount = 5
    
    private let mainRepository: MainRepository
    private let protectionInteractor: ProtectionInteracting
    private let uriInteractor: URIInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting
    
    init(
        mainRepository: MainRepository,
        protectionInteractor: ProtectionInteracting,
        uriInteractor: URIInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting
    ) {
        self.mainRepository = mainRepository
        self.protectionInteractor = protectionInteractor
        self.uriInteractor = uriInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.tagInteractor = tagInteractor
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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError> {
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
        
        let content = PasswordItemContent(
            name: name.nilIfEmpty,
            username: username.nilIfEmpty,
            password: encryptedPassword,
            notes: notes,
            iconType: iconType,
            uris: uris
        )
        
        guard let contentData = try? mainRepository.jsonEncoder.encode(content), let contentDataEnc = encryptData(contentData, isPassword: false, protectionLevel: protectionLevel) else {
            Log("Password interactor: Create password. Encryption error", module: .interactor, severity: .error)
            return .failure(.encryptionError)
        }
                
        mainRepository.createEncryptedPassword(
            passwordID: passwordID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: .login,
            contentVersion: 1,
            content: contentDataEnc,
            vaultID: selectedVault.vaultID,
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
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        uris: [PasswordURI]?,
        tagIds: [ItemTagID]?
    ) -> Result<Void, PasswordInteractorSaveError> {
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
        
        let content = PasswordItemContent(
            name: name.nilIfEmpty,
            username: username.nilIfEmpty,
            password: encryptedPassword,
            notes: notes,
            iconType: iconType,
            uris: uris
        )
        
        guard let contentData = try? mainRepository.jsonEncoder.encode(content), let contentDataEnc = encryptData(contentData, isPassword: false, protectionLevel: protectionLevel) else {
            return .failure(.encryptionError)
        }
        
        mainRepository.updateEncryptedPassword(
            passwordID: passwordID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            contentType: .login,
            contentVersion: 1,
            content: contentDataEnc,
            vaultID: selectedVault.vaultID,
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
    
    func getEncryptedPasswordEntity(passwordID: PasswordID) -> ItemEncryptedData? {
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
        deletedItemsInteractor.createDeletedItem(id: passwordID, kind: .login, deletedAt: date)
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
            modificationDate: date,
            trashedStatus: .no,
            protectionLevel: encryptedEntity.protectionLevel,
            contentType: encryptedEntity.contentType,
            contentVersion: encryptedEntity.contentVersion,
            content: encryptedEntity.content,
            vaultID: encryptedEntity.vaultID,
            tagIds: encryptedEntity.tagIds
        )
        deletedItemsInteractor.deleteDeletedItem(id: passwordID)
    }
    
    func encrypt(_ string: String, isPassword: Bool, protectionLevel: ItemProtectionLevel) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        return encryptData(data, isPassword: isPassword, protectionLevel: protectionLevel)
    }
    
    func encryptData(_ data: Data, isPassword: Bool, protectionLevel: ItemProtectionLevel) -> Data? {
        guard let key = mainRepository.getKey(isPassword: isPassword, protectionLevel: protectionLevel) else {
            return nil
        }
        return mainRepository.encrypt(data, key: key)
    }
    
    func decrypt(_ data: Data, isPassword: Bool, protectionLevel: ItemProtectionLevel) -> String? {
        guard let key = mainRepository.getKey(isPassword: isPassword, protectionLevel: protectionLevel),
              let decryptedData = mainRepository.decrypt(data, key: key) else {
            return nil
        }
        return String(data: decryptedData, encoding: .utf8)
    }
    
    func decryptContent<T>(_ result: T.Type, from data: Data, protectionLevel: ItemProtectionLevel) -> T? where T : Decodable {
        guard let key = mainRepository.getKey(isPassword: false, protectionLevel: protectionLevel),
              let decryptedData = mainRepository.decrypt(data, key: key) else {
            return nil
        }
        return try? mainRepository.jsonDecoder.decode(T.self, from: decryptedData)
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
            tagInteractor.listAllTags()
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
            case passwordData(ItemEncryptedData)
            case error
        }
        
        var fullyEncryptedBuffer: [DataFiller2] = [DataFiller2](repeating: .empty, count: passwordsEncrypted.count)
        
        fullyEncryptedBuffer.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                let current = passwordsEncrypted[i]
                
                let content = PasswordItemContent(
                    name: current.name,
                    username: current.username,
                    password: current.password,
                    notes: current.notes,
                    iconType: current.iconType,
                    uris: current.uris
                )
                if let contentData = try? mainRepository.jsonEncoder.encode(content), let contentDataEnc = encryptData(contentData, isPassword: false, protectionLevel: current.protectionLevel) {
                    buffer[i] = .passwordData(
                        ItemEncryptedData(
                            itemID: current.passwordID,
                            creationDate: current.creationDate,
                            modificationDate: current.modificationDate,
                            trashedStatus: current.trashedStatus,
                            protectionLevel: current.protectionLevel,
                            contentType: .login,
                            contentVersion: 1,
                            content: contentDataEnc,
                            vaultID: selectedVaultID,
                            tagIds: current.tagIds
                        )
                    )
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
        
        tagInteractor.batchUpdateTagsForNewEncryption(tags)
        
        saveStorage()
        
        completion(.success(()))
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
    
    func markAsTrashed(entity: PasswordData, encryptedEntity: ItemEncryptedData, date: Date) {
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
            modificationDate: date,
            trashedStatus: .yes(trashingDate: date),
            protectionLevel: encryptedEntity.protectionLevel,
            contentType: encryptedEntity.contentType,
            contentVersion: encryptedEntity.contentVersion,
            content: encryptedEntity.content,
            vaultID: encryptedEntity.vaultID,
            tagIds: encryptedEntity.tagIds
        )
    }
    
    func createEncryptedIconType(
        iconType: PasswordIconType,
        protectionLevel: ItemProtectionLevel
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
        protectionLevel: ItemProtectionLevel
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
        protectionLevel: ItemProtectionLevel,
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
