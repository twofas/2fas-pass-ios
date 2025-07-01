// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Foundation
import CloudKit

public enum MergeHandlerError: Error {
    case newerVersion
    case noLocalVault
    case incorrectEncryption
    case mergeError
    case syncNotAllowed
}

final class MergeHandler {
    var newerVersion: Callback?
    var incorrectEncryption: Callback?
    var syncNotAllowed: Callback?
    
    private let localStorage: LocalStorage
    private let cloudCacheStorage: CloudCacheStorage
    private let encryptionHandler: EncryptionHandler
    private let deviceID: DeviceID
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    
    private var isMultiDeviceSyncEnabled: Bool = false
    
    private var deleted: [DeletedItemID: Deleted] = [:]
    private var passwords: [PasswordID: Password] = [:]
    private var tags: [ItemTagID: Tag] = [:]
    private var deletedForRemoval: [Deleted] = []
    private var passwordsForRemoval: [Password] = []
    private var tagForRemoval: [Tag] = []
    
    // cloud
    private var recordsToCreateUpdate: [CKRecord] = []
    private var recordIDsForRemoval: [CKRecord.ID] = []
    
    // local storage
    private var deletedItemAdd: [DeletedItemData] = []
    private var deletedItemUpdate: [DeletedItemData] = []
    private var passwordsAdd: [PasswordData] = []
    private var passwordsUpdate: [PasswordData] = []
    private var tagAdd: [ItemTagData] = []
    private var tagUpdate: [ItemTagData] = []
    
    private var deletedIDsForDeletition: [DeletedItemID] = []
    private var passwordIDsForDeletition: [PasswordID] = [] // move to trash
    private var tagIDsForDeletition: [ItemTagID] = [] // move to trash
    
    // cloud storage
    private var cloudStorageDeletedItemAdd: [(deletedItem: DeletedItemData, metadata: Data)] = []
    private var cloudStorageDeletedItemUpdate: [(deletedItem: DeletedItemData, metadata: Data)] = []
    private var cloudStoragePasswordsAdd: [(password: PasswordEncryptedData, metadata: Data)] = []
    private var cloudStoragePasswordsUpdate: [(password: PasswordEncryptedData, metadata: Data)] = []
    private var cloudStorageTagAdd: [(tag: ItemTagEncryptedData, metadata: Data)] = []
    private var cloudStorageTagUpdate: [(tag: ItemTagEncryptedData, metadata: Data)] = []
    private var cloudStorageVaultAdd: VaultCloudData?
    private var cloudStorageDeletedIDsForDeletition: [DeletedItemID] = []
    private var cloudStoragePasswordIDsForDeletition: [PasswordID] = []
    private var cloudStorageTagIDsForDeletition: [ItemTagID] = []
    
    init(
        localStorage: LocalStorage,
        cloudCacheStorage: CloudCacheStorage,
        encryptionHandler: EncryptionHandler,
        deviceID: DeviceID,
        jsonDecoder: JSONDecoder,
        jsonEncoder: JSONEncoder
    ) {
        self.localStorage = localStorage
        self.cloudCacheStorage = cloudCacheStorage
        self.encryptionHandler = encryptionHandler
        self.deviceID = deviceID
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
    }
}

extension MergeHandler {
    func setMultiDeviceSyncEnabled(_ enabled: Bool) {
        isMultiDeviceSyncEnabled = enabled
    }
    
    var hasChanges: Bool {
        !deleted.isEmpty || !passwords.isEmpty || !deletedForRemoval.isEmpty || !passwordsForRemoval.isEmpty || (cloudStorageVaultAdd != nil)
    }
    
    func changesForCloud() -> (createUpdate: [CKRecord], delete: [CKRecord.ID]) {
        (createUpdate: recordsToCreateUpdate, delete: recordIDsForRemoval)
    }
    
    func applyChanges() -> Bool {
        // local
        deletedItemAdd.forEach(localStorage.createDeletedItem)
        deletedItemUpdate.forEach(localStorage.updateDeletedItem)
        
        var moveFromTrash: [PasswordID] = []
        let trashedPasswords = localStorage.listTrashedPasswords()
        passwordsAdd.forEach { pass in
            if trashedPasswords.contains(where: { $0.passwordID == pass.passwordID }) {
                passwordsUpdate.append(pass)
                moveFromTrash.append(pass.passwordID)
            } else {
                localStorage.createPassword(pass)
            }
        }
        passwordsUpdate.forEach(localStorage.updatePassword)
        moveFromTrash.forEach(localStorage.moveFromTrash)
        
        tagAdd.forEach(localStorage.createTag)
        tagUpdate.forEach(localStorage.updateTag)
        
        deletedIDsForDeletition.forEach(localStorage.removeDeletedItem)
        passwordIDsForDeletition.forEach(localStorage.removePassword)
        tagIDsForDeletition.forEach(localStorage.removeTag)
        
        let shouldRefreshLocalData = !passwordsAdd.isEmpty ||
        !passwordsUpdate.isEmpty ||
        !tagAdd.isEmpty ||
        !tagUpdate.isEmpty ||
        !deletedIDsForDeletition.isEmpty || // Password removed from trash, recovered tag
        !passwordIDsForDeletition.isEmpty ||// Password moved to trash
        !tagIDsForDeletition.isEmpty
        
        // cloud storage
        if let cloudStorageVaultAdd {
            cloudCacheStorage.createVault(vault: cloudStorageVaultAdd)
        }
        
        cloudStorageDeletedItemAdd
            .forEach {
                cloudCacheStorage
                    .createDeletedItem(.init(deletedItem: $0.deletedItem, metadata: $0.metadata))
            }
        cloudStorageDeletedItemUpdate
            .forEach {
                cloudCacheStorage
                    .updateDeletedItem(.init(deletedItem: $0.deletedItem, metadata: $0.metadata))
            }
        
        cloudStoragePasswordsAdd.forEach { cloudCacheStorage.createPassword(password: $0.password, metadata: $0.metadata) }
        cloudStoragePasswordsUpdate.forEach { cloudCacheStorage.updatePassword(password: $0.password, metadata: $0.metadata) }
        
        cloudStorageTagAdd.forEach { cloudCacheStorage.createTagItem(.init(tagItem: $0.tag, metadata: $0.metadata)) }
        cloudStorageTagUpdate.forEach { cloudCacheStorage.updateTagItem(.init(tagItem: $0.tag, metadata: $0.metadata)) }
        
        cloudStorageDeletedIDsForDeletition.forEach(cloudCacheStorage.deleteDeletedItem)
        cloudStoragePasswordIDsForDeletition.forEach(cloudCacheStorage.deletePassword)
        cloudStorageTagIDsForDeletition.forEach(cloudCacheStorage.deleteTag)
        
        localStorage.save()
        cloudCacheStorage.save()
        
        clear()
        
        return shouldRefreshLocalData
    }
    
    func clear() {
        deleted = [:]
        passwords = [:]
        deletedForRemoval = []
        passwordsForRemoval = []
        recordsToCreateUpdate = []
        recordIDsForRemoval = []
        deletedItemAdd = []
        deletedItemUpdate = []
        passwordsAdd = []
        passwordsUpdate = []
        tagAdd = []
        tagUpdate = []
        deletedIDsForDeletition = []
        passwordIDsForDeletition = []
        tagIDsForDeletition = []
        cloudStorageDeletedItemAdd = []
        cloudStorageDeletedItemUpdate = []
        cloudStoragePasswordsAdd = []
        cloudStoragePasswordsUpdate = []
        cloudStorageTagAdd = []
        cloudStorageTagUpdate = []
        cloudStorageDeletedIDsForDeletition = []
        cloudStoragePasswordIDsForDeletition = []
        cloudStorageTagIDsForDeletition = []
        cloudStorageVaultAdd = nil
    }
    
    func merge(date: Date, completion: @escaping (Result<Void, MergeHandlerError>) -> Void) {
        clear()
        LogZoneStart()
        
        // cloud
        let cloudDeletedItems = cloudCacheStorage.listAllDeletedItems()
        let cloudPasswords = cloudCacheStorage.listAllPasswords()
        let cloudTags = cloudCacheStorage.listAllTags()
        let cloudVaults = cloudCacheStorage.listAllVaults()
        
        // local storage
        let localDeletedItems = localStorage.listAllDeletedItems()
        let localPasswords = localStorage.listPasswords()
        let localTag = localStorage.listAllTags()
        guard let localVault = localStorage.currentVault() else {
            completion(.failure(MergeHandlerError.noLocalVault))
            return
        }
        
        var vaultAddIfDataModifed: VaultCloudData?
        
        // merge Vaults - create one in Cloud if missing
        if var cloudVault = cloudVaults.first(where: { $0.id == localVault.vaultID }) {
            if cloudVault.schemaVersion > encryptionHandler.currentCloudSchemaVersion {
                newerVersion?()
                completion(.failure(.newerVersion))
                return
            }
            
            if !ConstStorage.passwordWasChanged && !encryptionHandler.verifyEncryption(cloudVault) {
                incorrectEncryption?()
                completion(.failure(.incorrectEncryption))
                return
            }
            
            if cloudVault.deviceID != deviceID {
                if isMultiDeviceSyncEnabled {
                    cloudVault.update(deviceID: deviceID, updatedAt: date)
                    vaultAddIfDataModifed = cloudVault
                } else {
                    syncNotAllowed?()
                    completion(.failure(.syncNotAllowed))
                    return
                }
            }
            
        } else {
            if let vaultToAdd = createVaultToAdd(
                from: localVault,
                creationDate: date,
                modificationDate: date
            ) {
                cloudStorageVaultAdd = vaultToAdd.0
                recordsToCreateUpdate.append(vaultToAdd.1)
            } else {
                Log("Merge Handler: can't get vault data", module: .cloudSync, severity: .error)
            }
        }
        
        // merge Deleted Items
        deleted = localDeletedItems.reduce(into: [DeletedItemID: Deleted]()) { result, deletedPassword in
            result[deletedPassword.itemID] = Deleted.local(deletedPassword)
        }
        
        cloudDeletedItems.filter({ $0.deletedItem.vaultID == localVault.vaultID }).forEach { cloud in
            let itemID = cloud.deletedItem.itemID
            if let local = deleted[itemID] {
                if local.deletedAt.isSame(as: cloud.deletedItem.deletedAt) {
                    deleted[itemID] = nil
                } else if local.deletedAt.isBefore(cloud.deletedItem.deletedAt) {
                    deleted[itemID] = .cloud(deletedItem: cloud.deletedItem, metadata: cloud.metadata)
                }
            } else {
                deleted[itemID] = .cloud(deletedItem: cloud.deletedItem, metadata: cloud.metadata)
            }
        }
        
        // merge Tags
        tags = localTag.reduce(into: [ItemTagID: Tag]()) { result, itemTag in
            result[itemTag.tagID] = Tag.local(itemTag)
        }
        
        cloudTags.filter({ $0.tagItem.vaultID == localVault.vaultID }).forEach { cloud in
            let tagID = cloud.tagItem.tagID
            if let local = tags[tagID] {
                if local.modificationDate.isSame(as: cloud.tagItem.modificationDate) {
                    tags[tagID] = nil
                } else if local.modificationDate.isBefore(cloud.tagItem.modificationDate) {
                    tags[tagID] = .cloud(tag: cloud.tagItem, metadata: cloud.metadata)
                }
            } else {
                tags[tagID] = .cloud(tag: cloud.tagItem, metadata: cloud.metadata)
            }
        }
        
        // merge Passwords
        passwords = localPasswords.reduce(into: [PasswordID: Password]()) { result, localPass in
            result[localPass.passwordID] = Password.local(localPass)
        }
        
        cloudPasswords.values.filter({ $0.password.vaultID == localVault.vaultID }).forEach { cloudPass, metadata in
            let passwordID = cloudPass.passwordID
            if let local = passwords[passwordID] {
                if local.modificationDate.isSame(as: cloudPass.modificationDate) {
                    passwords[passwordID] = nil
                } else if local.modificationDate.isBefore(cloudPass.modificationDate) {
                    passwords[passwordID] = .cloud(password: cloudPass, metadata: metadata)
                }
            } else {
                passwords[passwordID] = .cloud(password: cloudPass, metadata: metadata)
            }
        }
        
        // merge changes with Deleted Passwords
        for deletedPassword in deleted where deletedPassword.value.isDeletedPassword {
            let passwordID = deletedPassword.key
            if let pass = passwords[passwordID] {
                // password was removed to trash
                if deletedPassword.value.deletedAt.isAfter(pass.modificationDate) {
                    passwordsForRemoval.append(pass)
                    passwords[passwordID] = nil
                } else { // password was restored from trash
                    deletedForRemoval.append(deletedPassword.value)
                    deleted[passwordID] = nil
                }
            }
        }
        
        // prepare changes for local and cloud
        // deleted items
        let localDeletedItemsIDs = localDeletedItems.map { $0.itemID }
        
        deleted.forEach { _, item in
            switch item {
            case .local(let deletedItem):
                var record: CKRecord?
                if let delItem = cloudDeletedItems.first(where: { $0.deletedItem.itemID == deletedItem.itemID }) {
                    record = DeletedItemRecord.recreate(with: delItem.metadata, data: deletedItem)
                    cloudStorageDeletedItemUpdate.append((deletedItem: deletedItem, metadata: delItem.metadata))
                } else {
                    if let ckRecord = DeletedItemRecord.create(data: deletedItem) {
                        cloudStorageDeletedItemAdd
                            .append((deletedItem: deletedItem, metadata: ckRecord.encodeSystemFields()))
                        record = ckRecord
                    }
                }
                if let record {
                    recordsToCreateUpdate.append(record)
                } else {
                    completion(.failure(MergeHandlerError.mergeError))
                    return
                }
            case .cloud(let deletedItem, _):
                if deletedItem.vaultID == localVault.vaultID {
                    if localDeletedItemsIDs.contains(where: { $0 == deletedItem.itemID }) {
                        deletedItemUpdate.append(deletedItem)
                    } else {
                        deletedItemAdd.append(deletedItem)
                    }
                }
            }
        }
        
        // tags
        let localTagIDs = localTag.map { $0.tagID }
        
        tags.forEach { _, tagEntry in
            switch tagEntry {
            case .local(let tag):
                var record: CKRecord?
                guard let encryptedTag = encryptionHandler.tagToTagEncrypted(tag) else {
                    Log("MergeHandler: Error encrypting tag", module: .backup, severity: .error)
                    completion(.failure(MergeHandlerError.mergeError))
                    return
                }
                if let tagItem = cloudTags.first(where: { $0.tagItem.tagID == tag.tagID }) {
                        record = TagRecord
                            .recreate(with: tagItem.metadata, data: encryptedTag)
                        cloudStorageTagUpdate.append((tag: encryptedTag, metadata: tagItem.metadata))
                } else {
                    if let ckRecord = TagRecord.create(data: encryptedTag) {
                        cloudStorageTagAdd
                            .append((tag: encryptedTag, metadata: ckRecord.encodeSystemFields()))
                        record = ckRecord
                    }
                }
                if let record {
                    recordsToCreateUpdate.append(record)
                } else {
                    completion(.failure(MergeHandlerError.mergeError))
                    return
                }
            case .cloud(let tagItem, _):
                guard let decryptedTag = encryptionHandler.tagEncyptedToTag(tagItem) else {
                    Log("MergeHandler: Error decrypting tag", module: .backup, severity: .error)
                    completion(.failure(MergeHandlerError.mergeError))
                    return
                }
                if tagItem.vaultID == localVault.vaultID {
                    if localTagIDs.contains(where: { $0 == tagItem.tagID }) {
                        tagUpdate.append(decryptedTag)
                    } else {
                        tagAdd.append(decryptedTag)
                    }
                }
            }
        }
        
        //
        
        let localPasswordIDs = localPasswords.map { $0.passwordID }
        
        Log("Merge Handler: preparing to parse password concurrently", module: .cloudSync)
        
        var passwordsProcessed: [PasswordEncryptionProcessed] = [PasswordEncryptionProcessed](
            repeating: .empty,
            count: passwords.count
        )
        
        let passwordsArray: [Password] = passwords.map { $0.value }
        
        passwordsProcessed.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                buffer[i] = {
                    switch passwordsArray[i] {
                    case .local(let passwordData):
                        if let val = self.encryptionHandler.passwordDataToPasswordEncryptedData(passwordData) {
                            return PasswordEncryptionProcessed.local(val)
                        }
                        return .empty
                    case .cloud(let password, _):
                        if let val = self.passwordEncryptedToPasswordData(password) {
                            return PasswordEncryptionProcessed.cloud(val, password.vaultID)
                        }
                        return .empty
                    }
                }()
            }
        }
        
        let countProcessed = passwordsProcessed.count
        
        passwordsProcessed.removeAll(where: { $0 == .empty })
        
        guard passwordsProcessed.count == countProcessed else {
            completion(.failure(.mergeError))
            return
        }
        
        Log("Merge Handler: passwords parsed concurrently", module: .cloudSync)
        
        passwordsProcessed.forEach { pass in
            switch pass {
            case .local(let passwordEncryptedData):
                var record: CKRecord?
                if let cloudPass = cloudPasswords[passwordEncryptedData.passwordID] {
                    record = PasswordRecord.recreate(jsonEncoder: jsonEncoder, metadata: cloudPass.metadata, data: passwordEncryptedData)
                    cloudStoragePasswordsUpdate.append((password: passwordEncryptedData, metadata: cloudPass.metadata))
                } else {
                    if let ckRecord = PasswordRecord.create(passwordEncryptedData: passwordEncryptedData, jsonEncoder: jsonEncoder) {
                        record = ckRecord
                        cloudStoragePasswordsAdd.append((password: passwordEncryptedData, metadata: ckRecord.encodeSystemFields()))
                    }
                }
                if let record {
                    recordsToCreateUpdate.append(record)
                } else {
                    completion(.failure(MergeHandlerError.mergeError))
                    return
                }
            case .cloud(let passwordData, let vaultID):
                if vaultID == localVault.vaultID {
                    if localPasswordIDs.contains(where: { $0 == passwordData.passwordID }) {
                        passwordsUpdate.append(passwordData)
                    } else {
                        passwordsAdd.append(passwordData)
                    }
                }
            default: break
            }
        }
        
        Log("Merge Handler: passwords prepared for cloud and storage", module: .cloudSync)
        let zoneID = CKRecordZone.ID.from(vaultID: localVault.vaultID)
        deletedForRemoval.forEach { del in
            switch del {
            case .local(let deletedItem):
                deletedIDsForDeletition.append(deletedItem.itemID)
            case .cloud(let deletedItem, _):
                cloudStorageDeletedIDsForDeletition.append(deletedItem.itemID)
                recordIDsForRemoval
                    .append(
                        CKRecord
                            .ID(recordName: DeletedItemRecord.createRecordName(for: deletedItem.itemID), zoneID: zoneID)
                    )
            }
        }
        
        passwordsForRemoval.forEach { pass in
            switch pass {
            case .local(let passwordData):
                passwordIDsForDeletition.append(passwordData.passwordID)
            case .cloud(let password, _):
                cloudStoragePasswordIDsForDeletition.append(password.passwordID)
                recordIDsForRemoval.append(CKRecord.ID(recordName: PasswordRecord.createRecordName(for: password.passwordID), zoneID: zoneID))
            }
        }
        
        if let vaultAddIfDataModifed {
            Log("Merge Handler: appending Vault with new modification date", module: .cloudSync)
            if let cloudVault = updateExistingCloudVault(vaultAddIfDataModifed),
               let record = VaultRecord.recreate(from: cloudVault) {
                cloudStorageVaultAdd = cloudVault
                recordsToCreateUpdate.append(record)
            } else {
                Log("Merge Handler: error appending Vault with new modification date", module: .cloudSync, severity: .error)
            }
        }
        
        LogZoneEnd()
        completion(.success(()))
    }
}

private extension MergeHandler {
    private func createDeletedItemRecord(from deletedItem: DeletedItemData) -> DeletedItemRecord? {
        guard let record = DeletedItemRecord.create(
            zoneID: .from(vaultID: deletedItem.vaultID),
            itemID: deletedItem.itemID,
            kind: deletedItem.kind,
            vaultID: deletedItem.vaultID,
            deletedAt: deletedItem.deletedAt
        ) else {
            return nil
        }
        return DeletedItemRecord(record: record)
    }
    
    private func createPasswordRecord(from passwordData: PasswordData) -> PasswordRecord? {
        guard let passwordEncrypted = encryptionHandler.passwordDataToPasswordEncryptedData(passwordData),
              let record = PasswordRecord.create(passwordEncryptedData: passwordEncrypted, jsonEncoder: jsonEncoder) else {
            return nil
        }
        return PasswordRecord(record: record)
    }
    
    private func createTagRecord(from tagData: ItemTagData) -> TagRecord? {
        guard let tagEncrypted = encryptionHandler.tagToTagEncrypted(tagData),
              let record = TagRecord.create(data: tagEncrypted) else {
            return nil
        }
        return TagRecord(record: record)
    }
    
    private func passwordEncryptedToPasswordData(_ passwordEncryptedData: PasswordEncryptedData) -> PasswordData? {
        encryptionHandler.passwordEncyptedToPasswordData(passwordEncryptedData)
    }
    
    private func createVaultToAdd(
        from vault: VaultEncryptedData,
        creationDate: Date?,
        modificationDate: Date?
    ) -> (VaultCloudData, CKRecord)? {
        guard let raw = encryptionHandler.vaultEncryptedDataToVaultRawData(vault),
              let vaultRecord = VaultRecord.create(from: raw),
              let ckRecord = vaultRecord.ckRecord
        else {
            // add error
            return nil
        }
        if let creationDate {
            vaultRecord.updateCreationDate(creationDate)
        }
        if let modificationDate {
            vaultRecord.updateModificationDate(modificationDate)
        }
        let recordData = vaultRecord.toRecordData()
        return (recordData, ckRecord)
    }
    
    private func updateExistingCloudVault(_ cloudVault: VaultCloudData) -> VaultCloudData? {
        encryptionHandler.updateCloudVault(cloudVault)
    }
}

private extension MergeHandler {
    enum Deleted: Hashable {
        case local(DeletedItemData)
        case cloud(deletedItem: DeletedItemData, metadata: Data)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .local(let deletedItem):
                hasher.combine(deletedItem.itemID)
            case .cloud(let deletedItem, _):
                hasher.combine(deletedItem.itemID)
            }
        }
        
        var deletedAt: Date {
            switch self {
            case .local(let deletedItem): deletedItem.deletedAt
            case .cloud(let deletedItem, _): deletedItem.deletedAt
            }
        }
        
        var isDeletedPassword: Bool {
            switch self {
            case .local(let deletedItemData): deletedItemData.kind == .login
            case .cloud(let deletedItemData, _): deletedItemData.kind == .login
            }
        }
    }
    
    enum Password: Hashable {
        case local(PasswordData)
        case cloud(password: PasswordEncryptedData, metadata: Data)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .local(let password):
                hasher.combine(password.passwordID)
            case .cloud(let password, _):
                hasher.combine(password.passwordID)
            }
        }
        
        var modificationDate: Date {
            switch self {
            case .local(let password): password.modificationDate
            case .cloud(let password, _): password.modificationDate
            }
        }
    }
    
    enum Tag: Hashable {
        case local(ItemTagData)
        case cloud(tag: ItemTagEncryptedData, metadata: Data)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .local(let tag):
                hasher.combine(tag.id)
            case .cloud(let tag, _):
                hasher.combine(tag.id)
            }
        }
        
        var modificationDate: Date {
            switch self {
            case .local(let tag): tag.modificationDate
            case .cloud(let tag, _): tag.modificationDate
            }
        }
    }
    
    enum PasswordEncryptionProcessed: Equatable {
        case empty
        case local(PasswordEncryptedData)
        case cloud(PasswordData, VaultID)
    }
}
