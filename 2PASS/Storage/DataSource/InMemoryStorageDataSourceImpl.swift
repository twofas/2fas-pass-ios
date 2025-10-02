// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CoreData

public final class InMemoryStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    
    public var storageError: ((String) -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "TwoPass",
            bundle: Bundle(for: InMemoryStorageDataSourceImpl.self),
            isPersistent: false
        )
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
    }
    
    public func loadStore(completion: @escaping LoadStoreCallback) {
        coreDataStack.loadStore(completion: completion)
    }
}

extension InMemoryStorageDataSourceImpl: InMemoryStorageDataSource {
    public func createItem(
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
        ItemEntity.create(
            on: context,
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
    
    public func updateItem(
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
        ItemEntity.update(
            on: context,
            for: itemID,
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
    
    public func batchUpdateRencryptedItems(_ items: [RawItemData], date: Date) {
        let listAll = ItemEntity.listItems(on: context, options: .all)
        for item in items {
            if let entity = listAll.first(where: { $0.itemID == item.id }) {
                ItemEntity.update(
                    on: context,
                    entity: entity,
                    modificationDate: date,
                    trashedStatus: item.trashedStatus,
                    protectionLevel: item.protectionLevel,
                    tagIds: item.tagIds,
                    name: item.name,
                    contentType: item.contentType,
                    contentVersion: item.contentVersion,
                    content: item.content
                )
            } else {
                Log("Error while searching for Password Entity \(item.id)")
            }
        }
    }
    
    public func getItemEntity(
        itemID: ItemID,
        checkInTrash: Bool
    ) -> RawItemData? {
        ItemEntity.getEntity(
            on: context,
            itemID: itemID,
            checkInTrash: checkInTrash
        )?.toData()
    }
    
    public func listItems(
        options: ItemsListOptions
    ) -> [RawItemData] {
        ItemEntity.listItems(on: context, options: options)
            .map { $0.toData() }
    }

    public func deleteItem(itemID: ItemID) {
        guard let entity = ItemEntity.getEntity(
            on: context,
            itemID: itemID,
            checkInTrash: true
        ) else { return }
        ItemEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllItemEntities() {
        ItemEntity.deleteAllItemEntities(on: context)
    }
}

extension InMemoryStorageDataSourceImpl {
    public func createTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        TagEntity
            .create(
                on: context,
                tagID: tagID,
                name: name,
                modificationDate: modificationDate,
                position: position,
                vaultID: vaultID,
                color: color
            )
    }
    
    public func updateTag(
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        TagEntity
            .update(
                on: context,
                tagID: tagID,
                name: name,
                modificationDate: modificationDate,
                position: position,
                vaultID: vaultID,
                color: color
            )
    }
    
    public func batchUpdateRencryptedTags(_ tags: [ItemTagData], date: Date) {
        let listAll = TagEntity.listItems(on: context, options: .all)
        for tag in tags {
            if let entity = listAll.first(where: { $0.tagID == tag.id }) {
                TagEntity
                    .update(
                        on: context,
                        entity: entity,
                        name: tag.name,
                        modificationDate: date,
                        position: Int16(tag.position),
                        vaultID: tag.vaultID,
                        color: tag.color?.hexString
                    )
            } else {
                Log("Error while searching for Tag Entity \(tag.id)")
            }
        }
    }
    
    public func getTagEntity(
        tagID: ItemTagID
    ) -> ItemTagData? {
        TagEntity.getEntity(on: context, tagID: tagID)?
            .toData()
    }
    
    public func listTags(
        options: TagListOptions
    ) -> [ItemTagData] {
        TagEntity.listItems(on: context, options: options)
            .map { $0.toData() }
    }
    
    public func deleteTag(tagID: ItemTagID) {
        guard let entity = TagEntity.getEntity(on: context, tagID: tagID) else {
            return
        }
        TagEntity.delete(on: context, entity: entity)
    }
    
    public func deleteAllTagEntities() {
        TagEntity.deleteAllTagEntities(on: context)
    }
}

extension InMemoryStorageDataSourceImpl {
    public func listUsernames() -> [String] {
        ItemEntity.listItems(on: context, options: .allNotTrashed)
            .compactMap {
                if let loginItem = ItemData($0.toData())?.asLoginItem {
                    return loginItem.username
                }
                return nil
            }
    }
    
    public func warmUp() {
        // Artifically calling out context so it will prepare storage for concurrent access
        try? coreDataStack.context.save()
    }
    
    public func save() {
        coreDataStack.save()
    }
}
