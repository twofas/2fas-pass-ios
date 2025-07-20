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
    private var items: [ItemID: Item] = [:]
    private var tags: [ItemTagID: Tag] = [:]
    private var deletedForRemoval: [Deleted] = []
    private var itemsForRemoval: [Item] = []
    private var tagForRemoval: [Tag] = []
    
    // cloud
    private var recordsToCreateUpdate: [CKRecord] = []
    private var recordIDsForRemoval: [CKRecord.ID] = []
    
    // local storage
    private var deletedItemAdd: [DeletedItemData] = []
    private var deletedItemUpdate: [DeletedItemData] = []
    private var itemsAdd: [ItemEncryptedData] = []
    private var itemsUpdate: [ItemEncryptedData] = []
    private var tagAdd: [ItemTagData] = []
    private var tagUpdate: [ItemTagData] = []
    
    private var deletedIDsForDeletition: [DeletedItemID] = []
    private var itemIDsForDeletition: [ItemID] = [] // move to trash
    private var tagIDsForDeletition: [ItemTagID] = [] // move to trash
    
    // cloud storage
    private var cloudStorageDeletedItemAdd: [(deletedItem: DeletedItemData, metadata: Data)] = []
    private var cloudStorageDeletedItemUpdate: [(deletedItem: DeletedItemData, metadata: Data)] = []
    private var cloudStorageItemAdd: [(item: ItemEncryptedData, metadata: Data)] = []
    private var cloudStorageItemUpdate: [(item: ItemEncryptedData, metadata: Data)] = []
    private var cloudStorageTagAdd: [(tag: ItemTagEncryptedData, metadata: Data)] = []
    private var cloudStorageTagUpdate: [(tag: ItemTagEncryptedData, metadata: Data)] = []
    private var cloudStorageVaultAdd: VaultCloudData?
    private var cloudStorageDeletedIDsForDeletition: [DeletedItemID] = []
    private var cloudStorageItemIDsForDeletition: [ItemID] = []
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
        !deleted.isEmpty || !items.isEmpty || !deletedForRemoval.isEmpty || !itemsForRemoval.isEmpty || (cloudStorageVaultAdd != nil)
    }
    
    func changesForCloud() -> (createUpdate: [CKRecord], delete: [CKRecord.ID]) {
        (createUpdate: recordsToCreateUpdate, delete: recordIDsForRemoval)
    }
    
    func applyChanges() -> Bool {
        // local
        deletedItemAdd.forEach(localStorage.createDeletedItem)
        deletedItemUpdate.forEach(localStorage.updateDeletedItem)
        
        var moveFromTrash: [PasswordID] = []
        let trashedItems = localStorage.listTrashedItemsIDs()
        itemsAdd.forEach { item in
            if trashedItems.contains(where: { $0 == item.itemID }) {
                itemsUpdate.append(item)
                moveFromTrash.append(item.itemID)
            } else {
                localStorage.createItem(item)
            }
        }
        itemsUpdate.forEach(localStorage.updateItem)
        moveFromTrash.forEach(localStorage.moveFromTrash)
        
        tagAdd.forEach(localStorage.createTag)
        tagUpdate.forEach(localStorage.updateTag)
        
        deletedIDsForDeletition.forEach(localStorage.removeDeletedItem)
        itemIDsForDeletition.forEach(localStorage.removeItem)
        tagIDsForDeletition.forEach(localStorage.removeTag)
        
        let shouldRefreshLocalData = !itemsAdd.isEmpty ||
        !itemsUpdate.isEmpty ||
        !tagAdd.isEmpty ||
        !tagUpdate.isEmpty ||
        !deletedIDsForDeletition.isEmpty || // Item removed from trash, recovered tag
        !itemIDsForDeletition.isEmpty ||// Item moved to trash
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
        
        cloudStorageItemAdd.forEach { cloudCacheStorage.createItem(item: $0.item, metadata: $0.metadata) }
        cloudStorageItemUpdate.forEach { cloudCacheStorage.updateItem(item: $0.item, metadata: $0.metadata) }
        
        cloudStorageTagAdd.forEach { cloudCacheStorage.createTagItem(.init(tagItem: $0.tag, metadata: $0.metadata)) }
        cloudStorageTagUpdate.forEach { cloudCacheStorage.updateTagItem(.init(tagItem: $0.tag, metadata: $0.metadata)) }
        
        cloudStorageDeletedIDsForDeletition.forEach(cloudCacheStorage.deleteDeletedItem)
        cloudStorageItemIDsForDeletition.forEach(cloudCacheStorage.deleteItem)
        cloudStorageTagIDsForDeletition.forEach(cloudCacheStorage.deleteTag)
        
        localStorage.save()
        cloudCacheStorage.save()
        
        clear()
        
        return shouldRefreshLocalData
    }
    
    func clear() {
        deleted = [:]
        items = [:]
        deletedForRemoval = []
        itemsForRemoval = []
        recordsToCreateUpdate = []
        recordIDsForRemoval = []
        deletedItemAdd = []
        deletedItemUpdate = []
        itemsAdd = []
        itemsUpdate = []
        tagAdd = []
        tagUpdate = []
        deletedIDsForDeletition = []
        itemIDsForDeletition = []
        tagIDsForDeletition = []
        cloudStorageDeletedItemAdd = []
        cloudStorageDeletedItemUpdate = []
        cloudStorageItemAdd = []
        cloudStorageItemUpdate = []
        cloudStorageTagAdd = []
        cloudStorageTagUpdate = []
        cloudStorageDeletedIDsForDeletition = []
        cloudStorageItemIDsForDeletition = []
        cloudStorageTagIDsForDeletition = []
        cloudStorageVaultAdd = nil
    }
    
    func merge(date: Date, completion: @escaping (Result<Void, MergeHandlerError>) -> Void) {
        clear()
        LogZoneStart()
        
        // cloud
        let cloudDeletedItems = cloudCacheStorage.listAllDeletedItems()
        let cloudItems = cloudCacheStorage.listAllItems()
        let cloudTags = cloudCacheStorage.listAllTags()
        let cloudVaults = cloudCacheStorage.listAllVaults()
        
        // local storage
        let localDeletedItems = localStorage.listAllDeletedItems()
        let localItems = localStorage.listItems()
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
                } else {
                    syncNotAllowed?()
                    completion(.failure(.syncNotAllowed))
                    return
                }
            }
            
            vaultAddIfDataModifed = cloudVault
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
        deleted = localDeletedItems.reduce(into: [DeletedItemID: Deleted]()) { result, deletedItem in
            result[deletedItem.itemID] = Deleted.local(deletedItem)
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
        
        // merge Items
        items = localItems.reduce(into: [ItemID: Item]()) { result, localItem in
            result[localItem.itemID] = Item.local(item: localItem)
        }
        
        cloudItems.values.filter({ $0.item.vaultID == localVault.vaultID }).forEach { cloudItem, metadata in
            let itemID = cloudItem.itemID
            if let local = items[itemID] {
                if local.modificationDate.isSame(as: cloudItem.modificationDate) {
                    items[itemID] = nil
                } else if local.modificationDate.isBefore(cloudItem.modificationDate) {
                    items[itemID] = .cloud(item: cloudItem, metadata: metadata)
                }
            } else {
                items[itemID] = .cloud(item: cloudItem, metadata: metadata)
            }
        }
        
        // merge changes with Deleted ITems
        for deletedItems in deleted where deletedItems.value.isDeletedItem {
            let itemID = deletedItems.key
            if let item = items[itemID] {
                // password was removed to trash
                if deletedItems.value.deletedAt.isAfter(item.modificationDate) {
                    itemsForRemoval.append(item)
                    items[itemID] = nil
                } else { // password was restored from trash
                    deletedForRemoval.append(deletedItems.value)
                    deleted[itemID] = nil
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
        
        let localItemIDs = localItems.map { $0.itemID }
        
        Log("Merge Handler: preparing to parse password concurrently", module: .cloudSync)
        
        var itemsProcessed: [ItemEncryptionProcessed] = [ItemEncryptionProcessed](
            repeating: .empty,
            count: items.count
        )
        
        let itemArray: [Item] = items.map { $0.value }
        
        itemsProcessed.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: buffer.count) { i in
                buffer[i] = {
                    switch itemArray[i] {
                    case .local(let localEncryptedItem):
                        if let val = self.encryptionHandler.localEncryptedItemToCloudEncryptedData(localEncryptedItem) {
                            return ItemEncryptionProcessed.local(val)
                        }
                        return .empty
                    case .cloud(let cloudEncryptedItem, _):
                        if let val = self.cloudEncryptedItemToLocalEncryptedItem(cloudEncryptedItem) {
                            return ItemEncryptionProcessed.cloud(val, cloudEncryptedItem.vaultID)
                        }
                        return .empty
                    }
                }()
            }
        }
        
        let countProcessed = itemsProcessed.count
        
        itemsProcessed.removeAll(where: { $0 == .empty })
        
        guard itemsProcessed.count == countProcessed else {
            completion(.failure(.mergeError))
            return
        }
        
        Log("Merge Handler: items parsed concurrently", module: .cloudSync)
        
        itemsProcessed.forEach { pass in
            switch pass {
            case .local(let itemEncryptedData):
                var record: CKRecord?
                if let cloudItem = cloudItems[itemEncryptedData.itemID] {
                    record = ItemRecord.recreate(jsonEncoder: jsonEncoder, metadata: cloudItem.metadata, data: itemEncryptedData)
                    cloudStorageItemUpdate.append((item: itemEncryptedData, metadata: cloudItem.metadata))
                } else {
                    if let ckRecord = ItemRecord.create(itemEncryptedData: itemEncryptedData, jsonEncoder: jsonEncoder) {
                        record = ckRecord
                        cloudStorageItemAdd.append((item: itemEncryptedData, metadata: ckRecord.encodeSystemFields()))
                    }
                }
                if let record {
                    recordsToCreateUpdate.append(record)
                } else {
                    completion(.failure(MergeHandlerError.mergeError))
                    return
                }
            case .cloud(let itemData, let vaultID):
                if vaultID == localVault.vaultID {
                    if localItemIDs.contains(where: { $0 == itemData.itemID }) {
                        itemsUpdate.append(itemData)
                    } else {
                        itemsAdd.append(itemData)
                    }
                }
            default: break
            }
        }
        
        Log("Merge Handler: items prepared for cloud and storage", module: .cloudSync)
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
        
        itemsForRemoval.forEach { pass in
            switch pass {
            case .local(let itemData):
                itemIDsForDeletition.append(itemData.itemID)
            case .cloud(let item, _):
                cloudStorageItemIDsForDeletition.append(item.itemID)
                recordIDsForRemoval.append(CKRecord.ID(recordName: ItemRecord.createRecordName(for: item.itemID), zoneID: zoneID))
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
    
    private func createItemRecord(from itemData: ItemEncryptedData) -> ItemRecord? {
        guard let record = ItemRecord.create(itemEncryptedData: itemData, jsonEncoder: jsonEncoder) else {
            return nil
        }
        return ItemRecord(record: record)
    }
    
    private func createTagRecord(from tagData: ItemTagData) -> TagRecord? {
        guard let tagEncrypted = encryptionHandler.tagToTagEncrypted(tagData),
              let record = TagRecord.create(data: tagEncrypted) else {
            return nil
        }
        return TagRecord(record: record)
    }
    
    private func cloudEncryptedItemToLocalEncryptedItem(_ cloudEncryptedData: ItemEncryptedData) -> ItemEncryptedData? {
        encryptionHandler.cloudEncryptedItemToLocalEncryptedItem(cloudEncryptedData)
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
        
        var isDeletedItem: Bool {
            switch self {
            case .local(let deletedItemData): deletedItemData.kind == .login
            case .cloud(let deletedItemData, _): deletedItemData.kind == .login
            }
        }
    }
    
    enum Item: Hashable {
        case local(item: ItemEncryptedData)
        case cloud(item: ItemEncryptedData, metadata: Data)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .local(let item):
                hasher.combine(item.itemID)
            case .cloud(let item, _):
                hasher.combine(item.itemID)
            }
        }
        
        var modificationDate: Date {
            switch self {
            case .local(let item): item.modificationDate
            case .cloud(let item, _): item.modificationDate
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
    
    enum ItemEncryptionProcessed: Equatable {
        case empty
        case local(ItemEncryptedData)
        case cloud(ItemEncryptedData, VaultID)
    }
}
