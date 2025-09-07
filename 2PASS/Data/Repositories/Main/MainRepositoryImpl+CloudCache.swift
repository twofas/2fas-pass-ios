// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Storage

extension MainRepositoryImpl {
    var cloudCacheIsInitializingNewStore: Bool {
        _cloudCacheInitilizingNewStore
    }
    
    func cloudCacheMarkInitializingNewStoreAsHandled() {
        _cloudCacheInitilizingNewStore = false
    }
    
    func cloudCacheCreateItem(
        itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID]?,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    ) {
        cloudCache.createCloudCachedItem(
            itemID: itemID,
            content: content,
            contentType: contentType,
            contentVersion: contentVersion,
            creationDate: creationDate,
            modificationDate: modificationDate,
            tagIds: tagIds,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    func cloudCacheUpdateItem(
        itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID]?,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    ) {
        cloudCache.updateCloudCachedItem(
            itemID: itemID,
            content: content,
            contentType: contentType,
            contentVersion: contentVersion,
            creationDate: creationDate,
            modificationDate: modificationDate,
            tagIds: tagIds,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    func cloudCacheGetItemEntity(itemID: ItemID) -> CloudDataItem? {
        cloudCache.getCloudCachedItemEntity(itemID: itemID)
    }
    
    func cloudCacheListItems(in vaultID: VaultID) -> [CloudDataItem] {
        cloudCache.listCloudCachedItems(in: vaultID)
    }
    
    func cloudCacheListAllItems() -> [CloudDataItem] {
        cloudCache.listAllCloudCachedItems()
    }
    
    func cloudCacheDeleteItem(itemID: ItemID) {
        cloudCache.deleteCloudCachedItem(itemID: itemID)
    }
    
    func cloudCacheDeleteAllItems() {
        cloudCache.deleteAllCloudCachedItems()
    }
    
    // MARK: - Cloud Cached Vaults
    
    func cloudCacheListVaults() -> [VaultCloudData] {
        cloudCache.listCloudCachedVaults()
    }
    
    func cloudCacheGetVault(for vaultID: VaultID) -> VaultCloudData? {
        cloudCache.getCloudCachedVault(for: vaultID)
    }
    
    func cloudCacheDeleteAllVaults() {
        cloudCache.deleteAllCloudCachedVaults()
    }
    
    func cloudCacheCreateVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        cloudCache.createCloudCachedVault(
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
    }
    
    func cloudCacheUpdateVault(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        cloudCache.updateCloudCachedVault(
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
    }
    
    func cloudCacheDeleteVault(_ vaultID: VaultID) {
        cloudCache.deleteCloudCachedVault(vaultID)
    }
    
    // MARK: - Cloud Cached Tags
    
    func cloudCacheCreateTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        cloudCache.createCloudCachedTag(
            metadata: metadata,
            tagID: tagID,
            name: name,
            color: color,
            position: position,
            modificationDate: modificationDate,
            vaultID: vaultID
        )
    }
    
    func cloudCacheUpdateTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        cloudCache.updateCloudCachedTag(
            metadata: metadata,
            tagID: tagID,
            name: name,
            color: color,
            position: position,
            modificationDate: modificationDate,
            vaultID: vaultID
        )
    }
    
    func cloudCacheGetTag(tagID: ItemTagID) -> CloudDataTagItem? {
        cloudCache.getCloudCachedTag(tagID: tagID)
    }
    
    func cloudCacheListTags(in vaultID: VaultID, limit: Int?) -> [CloudDataTagItem] {
        cloudCache.listCloudCachedTags(in: vaultID, limit: limit)
    }
    
    func cloudCacheListAllTags(limit: Int?) -> [CloudDataTagItem] {
        cloudCache.listAllCloudCachedTags(limit: limit)
    }
    
    func cloudCacheDeleteTag(tagID: ItemTagID) {
        cloudCache.deleteCloudCachedTag(tagID: tagID)
    }
    
    func cloudCacheDeleteAllTags() {
        cloudCache.deleteAllCloudCachedTags()
    }
    
    // MARK: - Deleted Items
     
    func cloudCacheCreateDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        cloudCache
            .createCloudCachedDeletedItem(
                metadata: metadata,
                itemID: itemID,
                kind: kind,
                deletedAt: deletedAt,
                in: vaultID
            )
    }
    
    func cloudCacheUpdateDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        cloudCache
            .updateCloudCachedDeletedItem(
                metadata: metadata,
                itemID: itemID,
                kind: kind,
                deletedAt: deletedAt,
                in: vaultID
            )
    }

    func cloudCacheListDeletedItems(in vaultID: VaultID, limit: Int?) -> [CloudDataDeletedItem] {
        cloudCache.listCloudCachedDeletedItems(in: vaultID, limit: limit)
    }
    
    func cloudCacheListAllDeletedItems(limit: Int?) -> [CloudDataDeletedItem] {
        cloudCache.listAllCloudCachedDeletedItems(limit: limit)
    }
    
    func cloudCacheDeleteDeletedItem(itemID: DeletedItemID) {
        cloudCache.deleteCloudCachedDeletedItem(itemID: itemID)
    }
    
    func cloudCacheDeleteAllDeletedItems() {
        cloudCache.cloudCacheDeleteAllDeletedItems()
    }
    
    // MARK: - Save
    
    func cloudCacheSave() {
        cloudCache.save()
    }
}
