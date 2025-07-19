// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

public protocol CloudCacheStorageDataSource: AnyObject {
    var storageError: ((String) -> Void)? { get set }
    var initilizingNewStore: (() -> Void)? { get set }
    
    // MARK: Cloud Cached Passwords
    
    func createCloudCachedItem(
        itemID: ItemID,
        content: Data?,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID],
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    )
    
    func updateCloudCachedItem(
        itemID: ItemID,
        content: Data?,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        tagIds: [ItemTagID],
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        vaultID: VaultID,
        metadata: Data
    )
    
    func getCloudCachedItemEntity(passwordID: ItemID) -> CloudDataItem?
    
    func listCloudCachedItems(in vaultID: VaultID) -> [CloudDataItem]
    func listAllCloudCachedItems() -> [CloudDataItem]
        
    func deleteCloudCachedItem(itemID: ItemID)
    func deleteAllCloudCachedItems()
    
    // MARK: Cloud Cached Vaults
    
    func listCloudCachedVaults() -> [VaultCloudData]
    func getCloudCachedVault(for vaultID: VaultID) -> VaultCloudData?
    func createCloudCachedVault(
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
    )
    func updateCloudCachedVault(
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
    )
    func deleteCloudCachedVault(_ vaultID: VaultID)
    func deleteAllCloudCachedVaults()
    
    // MARK: Cloud Cached Tags
    
    func createCloudCachedTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    )
    
    func updateCloudCachedTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID,
    )
    
    func getCloudCachedTag(tagID: ItemTagID) -> CloudDataTagItem?
    
    func listCloudCachedTags(in vaultID: VaultID, limit: Int?) -> [CloudDataTagItem]
    func listAllCloudCachedTags(limit: Int?) -> [CloudDataTagItem]
    
    func deleteCloudCachedTag(tagID: ItemTagID)
    func deleteAllCloudCachedTags()
    
    // MARK: Deleted Items
    
    func createCloudCachedDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    )
    func updateCloudCachedDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    )
    func listCloudCachedDeletedItems(in vaultID: VaultID, limit: Int?) -> [CloudDataDeletedItem]
    func listAllCloudCachedDeletedItems(limit: Int?) -> [CloudDataDeletedItem]
    func deleteCloudCachedDeletedItem(itemID: DeletedItemID)
    func cloudCacheDeleteAllDeletedItems()
    
    // MARK: Storage
    
    func warmUp()
    func save()
}
