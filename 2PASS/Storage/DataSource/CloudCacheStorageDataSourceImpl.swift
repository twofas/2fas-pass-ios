// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CoreData

public final class CloudCacheStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    
    public var storageError: ((String) -> Void)?
    public var initilizingNewStore: (() -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "CloudCache2",
            bundle: Bundle(for: CloudCacheStorageDataSourceImpl.self),
            isPersistent: true
        )
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.initilizingNewStore = { [weak self] in self?.initilizingNewStore?() }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
        coreDataStack.loadStore { success in
            guard success else { fatalError("Failed to load CloudCache store") }
            Log("CloudCache storage initialized")
        }
    }
}

extension CloudCacheStorageDataSourceImpl: CloudCacheStorageDataSource {
    // MARK: Cloud Cached Items
    
    public func createCloudCachedItem(
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
        ItemCachedEntity.create(
            on: context,
            itemID: itemID,
            content: content,
            contentType: contentType,
            contentVersion: contentVersion,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            metadata: metadata,
            vaultID: vaultID
        )
    }
    
    public func updateCloudCachedItem(
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
        ItemCachedEntity.update(
            on: context,
            for: itemID,
            content: content,
            contentType: contentType,
            contentVersion: contentVersion,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            metadata: metadata
        )
    }
    
    public func getCloudCachedItemEntity(passwordID: ItemID) -> CloudDataItem? {
        guard let entity = ItemCachedEntity.getEntity(on: context, itemID: passwordID) else {
            return nil
        }
        return .init(item: entity.toData(), metadata: entity.metadata)
    }
    
    public func listCloudCachedItems(in vaultID: VaultID) -> [CloudDataItem] {
        ItemCachedEntity.listItemsInVault(on: context, vaultID: vaultID)
            .map { .init(item: $0.toData(), metadata: $0.metadata) }
    }
    
    public func listAllCloudCachedItems() -> [CloudDataItem] {
        ItemCachedEntity.listItems(on: context)
            .map { .init(item: $0.toData(), metadata: $0.metadata) }
    }
    
    public func deleteCloudCachedItem(itemID: ItemID) {
        guard let entity = ItemCachedEntity.getEntity(on: context, itemID: itemID) else { return }
        ItemCachedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllCloudCachedItems() {
        let items = ItemCachedEntity.listItems(on: context)
        items.forEach { entity in
            context.delete(entity)
        }
    }
    
    // MARK: Encrypted Vaults
    
    public func listCloudCachedVaults() -> [VaultCloudData] {
        VaultCachedEntity.listItems(on: context)
            .map { $0.toData() }
    }
    
    public func getCloudCachedVault(for vaultID: VaultID) -> VaultCloudData? {
        guard let vault = VaultCachedEntity.getEntity(on: context, vaultID: vaultID) else {
            return nil
        }
        return vault.toData()
    }
    
    public func createCloudCachedVault(
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
        VaultCachedEntity.create(
            on: context,
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
    
    public func updateCloudCachedVault(
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
        VaultCachedEntity.update(
            on: context,
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
    
    public func deleteCloudCachedVault(_ vaultID: VaultID) {
        guard let entity = VaultCachedEntity.getEntity(on: context, vaultID: vaultID) else { return }
        VaultCachedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllCloudCachedVaults() {
        let vaults = VaultCachedEntity.listItems(on: context)
        vaults.forEach { entity in
            context.delete(entity)
        }
    }
    
    // MARK: Cloud Cached Tags
    
    public func createCloudCachedTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        TagCachedEntity.create(
            on: context,
            tagID: tagID,
            name: name,
            color: color,
            position: position,
            modificationDate: modificationDate,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func updateCloudCachedTag(
        metadata: Data,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID
    ) {
        TagCachedEntity.update(
            on: context,
            tagID: tagID,
            name: name,
            color: color,
            position: position,
            modificationDate: modificationDate,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func getCloudCachedTag(tagID: ItemTagID) -> CloudDataTagItem? {
        guard let entity = TagCachedEntity.getEntity(on: context, tagID: tagID) else {
            return nil
        }
        return .init(tagItem: entity.toData, metadata: entity.metadata)
    }
    
    public func listCloudCachedTags(in vaultID: VaultID, limit: Int?) -> [CloudDataTagItem] {
        TagCachedEntity.listItems(on: context, vaultID: vaultID, limit: limit)
            .map { .init(tagItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func listAllCloudCachedTags(limit: Int?) -> [CloudDataTagItem] {
        TagCachedEntity.listItems(on: context, vaultID: nil, limit: limit)
            .map { .init(tagItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func deleteCloudCachedTag(tagID: ItemTagID) {
        guard let entity = TagCachedEntity.getEntity(on: context, tagID: tagID) else {
            return
        }
        TagCachedEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllCloudCachedTags() {
        TagCachedEntity.listItems(on: context, vaultID: nil).forEach { entity in
            context.delete(entity)
        }
    }
    
    public func createCloudCachedDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        DeletedItemCachedEntity.create(
            on: context,
            itemID: itemID,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func updateCloudCachedDeletedItem(
        metadata: Data,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        in vaultID: VaultID
    ) {
        DeletedItemCachedEntity.update(
            on: context,
            itemID: itemID,
            kind: kind,
            deletedAt: deletedAt,
            vaultID: vaultID,
            metadata: metadata
        )
    }
    
    public func listCloudCachedDeletedItems(in vaultID: VaultID, limit: Int?) -> [CloudDataDeletedItem] {
        DeletedItemCachedEntity.listItems(on: context, vaultID: vaultID, limit: limit)
            .map { .init(deletedItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func listAllCloudCachedDeletedItems(limit: Int?) -> [CloudDataDeletedItem] {
        DeletedItemCachedEntity.listItems(on: context, vaultID: nil)
            .map { .init(deletedItem: $0.toData, metadata: $0.metadata) }
    }
    
    public func deleteCloudCachedDeletedItem(itemID: DeletedItemID) {
        guard let entity = DeletedItemCachedEntity.getEntity(on: context, itemID: itemID) else {
            return
        }
        DeletedItemCachedEntity.delete(on: context, entity: entity)
    }
    
    public func cloudCacheDeleteAllDeletedItems() {
        DeletedItemCachedEntity.listItems(on: context, vaultID: nil).forEach { entity in
            context.delete(entity)
        }
    }
    
    public func warmUp() {
        // Artifically calling out context so it will prepare storage for concurrent access
        coreDataStack.context.performAndWait { [weak self] in
            try? self?.coreDataStack.context.save()
        }
    }
    
    public func save() {
        coreDataStack.save()
    }
}
