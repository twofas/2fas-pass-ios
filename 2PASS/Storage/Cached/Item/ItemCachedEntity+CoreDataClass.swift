//
//  ItemCachedEntity+CoreDataClass.swift
//  Backup
//
//  Created by Zbigniew Cisiński on 19/07/2025.
//  Copyright © 2025 Two Factor Authentication Service, Inc. All rights reserved.
//
//

import Foundation
import CoreData
import Common

final class ItemCachedEntity: NSManagedObject {
    @discardableResult
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        metadata: Data,
        vaultID: VaultID
    ) -> ItemCachedEntity {
        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! ItemCachedEntity
            
            entity.itemID = itemID
            entity.content = content
            entity.contentType = contentType.rawValue
            entity.contentVersion = Int16(contentVersion)
            entity.creationDate = creationDate
            entity.modificationDate = modificationDate
            
            switch trashedStatus {
            case .no:
                entity.isTrashed = false
                entity.trashingDate = nil
            case .yes(let trashingDate):
                entity.isTrashed = true
                entity.trashingDate = trashingDate
            }
            
            entity.protectionLevel = protectionLevel.rawValue
            entity.tagIds = tagIds
            entity.metadata = metadata
            entity.vaultID = vaultID
            
            return entity
        }
    }
    
    @discardableResult
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        content: Data,
        contentType: ItemContentType,
        contentVersion: Int,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?,
        metadata: Data
    ) -> ItemCachedEntity? {
        context.performAndWait {
            guard let entity = getEntity(on: context, itemID: itemID) else {
                Log("ItemCachedEntity: Can't find cached entity for itemID: \(itemID)", module: .storage)
                return nil
            }
            
            entity.content = content
            entity.contentType = contentType.rawValue
            entity.contentVersion = Int16(contentVersion)
            entity.creationDate = creationDate
            entity.modificationDate = modificationDate
            
            switch trashedStatus {
            case .no:
                entity.isTrashed = false
                entity.trashingDate = nil
            case .yes(let trashingDate):
                entity.isTrashed = true
                entity.trashingDate = trashingDate
            }
            
            entity.protectionLevel = protectionLevel.rawValue
            entity.tagIds = tagIds
            entity.metadata = metadata
            
            return entity
        }
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        itemID: ItemID
    ) -> ItemCachedEntity? {
        let fetchRequest = ItemCachedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        fetchRequest.includesPendingChanges = true

        var list: [ItemCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("ItemCachedEntity in Storage getEntity: \(err.localizedDescription)", module: .storage, severity: .error)
            // swiftlint:enable line_length
            return nil
        }

        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }

        return list.first
    }
    
    @nonobjc static func deleteAllCachedItems(on context: NSManagedObjectContext) {
        let items = listItems(
            on: context,
            predicate: NSPredicate(format: "isTrashed == FALSE"),
            includesPropertyValues: false
        )
        
        items.forEach { entity in
            context.delete(entity)
        }
    }
    
    @nonobjc static func listItemsInVault(
        on context: NSManagedObjectContext,
        vaultID: VaultID
    ) -> [ItemCachedEntity] {
        listItems(on: context, predicate: NSPredicate(format: "vaultID == %@", vaultID as CVarArg))
    }

    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate? = nil,
        includesPropertyValues: Bool = true
    ) -> [ItemCachedEntity] {
        let fetchRequest = ItemCachedEntity.fetchRequest()
        fetchRequest.includesPropertyValues = includesPropertyValues
        if let predicate {
            fetchRequest.predicate = predicate
        }

        var list: [ItemCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("ItemCachedEntity in Storage listItems: \(err.localizedDescription)", module: .storage, severity: .error)
            // swiftlint:enable line_length
            return []
        }

        return list
    }

    @nonobjc static func delete(on context: NSManagedObjectContext, entity: ItemCachedEntity) {
        Log("ItemCachedEntity: Deleting entity of type: ItemCachedEntity", module: .storage, save: false)
        context.delete(entity)
    }
}
