// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(PasswordEntity)
final class PasswordEntity: NSManagedObject {
    @nonobjc static let entityName = "PasswordEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: String,
        contentVersion: Int,
        content: Data
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! PasswordEntity
        
        entity.itemID = itemID
        entity.name = name
        entity.creationDate = creationDate
        entity.modificationDate = modificationDate
        entity.contentData = content
        entity.contentType = contentType
        entity.contentVersion = Int16(contentVersion)
        
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
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: String,
        contentVersion: Int,
        content: Data
    ) {
        guard let entity = getEntity(on: context, itemID: itemID, checkInTrash: true) else {
            Log("Can't find entity for itemID: \(itemID)", module: .storage)
            return
        }
        
        update(
            on: context,
            entity: entity,
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
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        entity: PasswordEntity,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        name: String?,
        contentType: String,
        contentVersion: Int,
        content: Data
    ) {
        entity.modificationDate = modificationDate
        entity.name = name
        entity.contentData = content
        entity.contentType = contentType
        entity.contentVersion = Int16(contentVersion)
        
        
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
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        itemID: UUID,
        checkInTrash: Bool
    ) -> PasswordEntity? {
        let list = listItems(
            on: context,
            options: checkInTrash ? .findExistingByItemID(itemID) : .findNotTrashedByItemID(itemID)
        )
        
        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }
        
        return list.first
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        options: PasswordListOptions
    ) -> [PasswordEntity] {
        listItems(on: context, predicate: options.predicate, sortDescriptors: options.sortDescriptors)
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: PasswordEntity) {
        Log("Deleting entity of type: \(entity)", module: .storage)
        context.delete(entity)
    }
    
    @nonobjc static func deleteAllPasswordEntities(on context: NSManagedObjectContext) {
        let items = listItems(on: context, options: .allNotTrashed)
        items.forEach { item in
            context.delete(item)
        }
    }
}

private extension PasswordEntity {
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?
    ) -> [PasswordEntity] {
        let fetchRequest = PasswordEntity.fetchRequest()
        if let predicate {
            fetchRequest.predicate = predicate
        }
        if let sortDescriptors {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        
        var list: [PasswordEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("PasswordEntity in Storage listItems(filter:\(String(describing: predicate)): \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
        
        return list
    }
}
