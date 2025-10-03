// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Storage

extension MainRepositoryImpl {
    
    // MARK: Items
    
    func createItem(
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        inMemoryStorage?.createItem(
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content
        )
    }
    
    func updateMetadataItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int
    ) {
        inMemoryStorage?.updateMetadataItem(
            itemID: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion
        )
    }
    
    func updateItem(
        itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        inMemoryStorage?.updateItem(
            itemID: itemID,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content
        )
    }
    
    func updateItems(_ items: [RawItemData]) {
        items.forEach { item in
            inMemoryStorage?.updateItem(
                itemID: item.id,
                modificationDate: item.modificationDate,
                trashedStatus: item.trashedStatus,
                protectionLevel: item.protectionLevel,
                tagIds: item.tagIds,
                name: item.name,
                contentType: item.contentType,
                contentVersion: item.contentVersion,
                content: item.content
            )
        }
    }
    
    func itemsBatchUpdate(_ items: [RawItemData]) {
        inMemoryStorage?.batchUpdateRencryptedItems(items, date: currentDate)
    }
    
    func getItemEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> ItemData? {
        inMemoryStorage?.getItemEntity(itemID: itemID, checkInTrash: checkInTrash)
    }
    
    func listItems(
        options: ItemsListOptions
    ) -> [ItemData] {
        inMemoryStorage?.listItems(options: options) ?? []
    }
    
    func listTrashedItems() -> [ItemData] {
        inMemoryStorage?.listItems(options: .allTrashed) ?? []
    }
    
    func deleteItem(itemID: ItemID) {
        inMemoryStorage?.deleteItem(itemID: itemID)
    }
    
    func deleteAllItems() {
        inMemoryStorage?.deleteAllItemEntities()
    }
    
    // MARK: Tags
    
    func createTag(_ tag: ItemTagData) {
        inMemoryStorage?
            .createTag(
                tagID: tag.tagID,
                name: tag.name,
                modificationDate: tag.modificationDate,
                position: Int16(tag.position),
                vaultID: tag.vaultID,
                color: tag.color
            )
    }
    
    func updateTag(_ tag: ItemTagData) {
        inMemoryStorage?.updateTag(
            tagID: tag.tagID,
            name: tag.name,
            modificationDate: tag.modificationDate,
            position: Int16(tag.position),
            vaultID: tag.vaultID,
            color: tag.color)
    }
    
    func deleteTag(tagID: ItemTagID) {
        inMemoryStorage?.deleteTag(tagID: tagID)
    }
    
    func listTags(options: TagListOptions) -> [ItemTagData] {
        inMemoryStorage?.listTags(options: options) ?? []
    }
    
    func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date) {
        inMemoryStorage?.batchUpdateRencryptedTags(tags, date: date)
    }
    
    // MARK: Other
    
    func saveStorage() {
        Log("Save In-memory Storage", module: .mainRepository)
        inMemoryStorage?.save()
    }
    
    func listUsernames() -> [String] {
        inMemoryStorage?.listUsernames() ?? []
    }
    
    func createInMemoryStorage() {
        let storage = InMemoryStorageDataSourceImpl()
        storage.storageError = { [weak self] in self?.storageError?($0) }
        storage.loadStore { [weak self] success in
            guard success else { fatalError("Failed to load InMemory store") }
            self?.inMemoryStorage = storage
            self?.inMemoryStorage?.warmUp()
        }
    }
    
    func destroyInMemoryStorage() {
        inMemoryStorage = nil
    }
    
    var hasInMemoryStorage: Bool {
        inMemoryStorage != nil
    }
}
