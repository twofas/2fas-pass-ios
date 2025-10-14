// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

final class ItemEncryptedEntity: NSManagedObject {
    @nonobjc private static let entityName = "ItemEncryptedEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        itemID: ItemID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        tagIds: [ItemTagID]?
    ) -> ItemEncryptedEntity {
        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! ItemEncryptedEntity
            
            entity.itemID = itemID
            
            entity.creationDate = creationDate
            entity.modificationDate = modificationDate
            
            switch trashedStatus {
            case .no:
                entity.isTrashed = false
            case .yes(let trashingDate):
                entity.isTrashed = true
                entity.trashingDate = trashingDate
            }
            
            entity.level = protectionLevel.rawValue
            entity.tagIds = tagIds
            
            entity.contentType = contentType.rawValue
            entity.contentVersion = Int16(contentVersion)
            entity.content = content
            
            return entity
        }
    }
    
    @discardableResult
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        for itemID: ItemID,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        tagIds: [ItemTagID]?
    ) -> ItemEncryptedEntity? {
        context.performAndWait {
            guard let entity = getEntity(on: context, itemID: itemID) else {
                Log("Can't find encrypted entity for itemID: \(itemID)", module: .storage)
                return nil
            }
            
            update(
                on: context,
                entity: entity,
                modificationDate: modificationDate,
                trashedStatus: trashedStatus,
                protectionLevel: protectionLevel,
                contentType: contentType,
                contentVersion: contentVersion,
                content: content,
                tagIds: tagIds
            )
            
            return entity
        }
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        entity: ItemEncryptedEntity,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        tagIds: [ItemTagID]?
    ) {
        entity.modificationDate = modificationDate
        
        switch trashedStatus {
        case .no:
            entity.isTrashed = false
        case .yes(let trashingDate):
            entity.isTrashed = true
            entity.trashingDate = trashingDate
        }
        
        entity.level = protectionLevel.rawValue
        entity.tagIds = tagIds
        
        entity.contentType = contentType.rawValue
        entity.contentVersion = Int16(contentVersion)
        entity.content = content
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        itemID: ItemID
    ) -> ItemEncryptedEntity? {
        let fetchRequest = ItemEncryptedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        fetchRequest.includesPendingChanges = true
        
        var list: [ItemEncryptedEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("ItemEncryptedEntity in Storage listItems: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return nil
        }
        
        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            Log("ItemEncryptedEntity: Error while fetching entity with ItemID: \(itemID). There's more than one. Correcting!", severity: .error)
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }
        
        return list.first
    }
    
    @nonobjc static func deleteAllEncryptedItems(on context: NSManagedObjectContext, vaultID: VaultID?) {
        let items = listItems(
            on: context,
            predicate: NSPredicate(format: "isTrashed == FALSE"),
            includesPropertyValues: false,
            vaultID: vaultID
        )
        
        items.forEach { entity in
            context.delete(entity)
        }
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate? = nil,
        includesPropertyValues: Bool = true,
        vaultID: VaultID? = nil
    ) -> [ItemEncryptedEntity] {
        let fetchRequest = ItemEncryptedEntity.fetchRequest()
        fetchRequest.includesPropertyValues = includesPropertyValues
        if let predicate {
            if let vaultID {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    predicate,
                    NSPredicate(format: "vault.vaultID == %@", vaultID as CVarArg)
                ])
            } else {
                fetchRequest.predicate = predicate
            }
        }
        
        var list: [ItemEncryptedEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("PasswordEncryptedEntity in Storage listItems: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
        
        return list
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        excludeProtectionLevels: Set<ItemProtectionLevel>,
        vaultID: VaultID? = nil
    ) -> [ItemEncryptedEntity] {
        listItems(
            on: context,
            predicate:  NSPredicate(format: "NOT (level IN %@)", excludeProtectionLevels.map({ $0.rawValue })),
            vaultID: vaultID
        )
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: ItemEncryptedEntity) {
        Log("PasswordEncryptedEntity: Deleting entity of type: \(entity)", module: .storage)
        context.delete(entity)
    }
}
