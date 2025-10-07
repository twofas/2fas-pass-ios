// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(ItemMetadataEntity)
class ItemMetadataEntity: NSManagedObject {
    @nonobjc static let entityName = "ItemMetadataEntity"
    
    private static func entity(for contentType: ItemContentType) -> ItemMetadataEntity.Type {
        switch contentType {
        case .login: LoginEntity.self
        case .secureNote: SecureNoteEntity.self
        case .unknown: RawEntity.self
        }
    }
    
    @nonobjc static func createItem(
        on context: NSManagedObjectContext,
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
        entity(for: contentType).create(
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
    
    @nonobjc static func updateMetadata(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int
    ) {
        guard let entity = getEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find entity for itemID: \(itemID)", module: .storage)
            return
        }
        
        updateMetadata(
            on: context,
            entity: entity,
            modificationDate: modificationDate,
            trashedStatus: trashedStatus,
            protectionLevel: protectionLevel,
            tagIds: tagIds,
            name: name,
            contentType: contentType,
            contentVersion: contentVersion
        )
    }
    
    @nonobjc static func updateMetadata(
        on context: NSManagedObjectContext,
        entity: ItemMetadataEntity,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int
    ) {
        entity.modificationDate = modificationDate
        entity.name = name
        
        switch trashedStatus {
        case .no:
            entity.isTrashed = false
        case .yes(let trashingDate):
            entity.isTrashed = true
            entity.trashingDate = trashingDate
        }
        
        entity.level = protectionLevel.rawValue
        
        if let tagIds, tagIds.isEmpty == false {
            entity.tagIds = tagIds
        } else {
            entity.tagIds = nil
        }
        
        entity.contentType = contentType.rawValue
        entity.contentVersion = Int16(contentVersion)
    }
    
    @nonobjc static func updateItem(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        entity(for: contentType).update(
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
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> ItemMetadataEntity? {
        let list = listItems(
            on: context,
            options: checkInTrash ? .findExistingByItemID(itemID) : .findNotTrashedByItemID(itemID)
        )
        return list.first
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        options: ItemsListOptions
    ) -> [ItemMetadataEntity] {
        listItems(on: context, predicate: options.predicate, sortDescriptors: options.sortDescriptors)
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: ItemMetadataEntity) {
        Log("Deleting entity of type: \(entity)", module: .storage)
        context.delete(entity)
    }
    
    @nonobjc static func deleteAllItemEntities(on context: NSManagedObjectContext) {
        let items = listItems(on: context, options: .allNotTrashed)
        items.forEach { item in
            context.delete(item)
        }
    }
    
    @nonobjc class func create(
        on context: NSManagedObjectContext,
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
        fatalError("Should be overridden by subclasses")
    }
    
    @nonobjc class func update(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data
    ) {
        fatalError("Should be overridden by subclasses")
    }
    
    func toData() -> ItemData {
        fatalError("Should be overridden by subclasses")
    }
}

private extension ItemMetadataEntity {
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?
    ) -> [ItemMetadataEntity] {
        let fetchRequest = ItemMetadataEntity.fetchRequest()
        if let predicate {
            fetchRequest.predicate = predicate
        }
        if let sortDescriptors {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        
        var list: [ItemMetadataEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("ItemMetadataEntity in Storage listItems(filter:\(String(describing: predicate)): \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
        
        return list
    }
}
