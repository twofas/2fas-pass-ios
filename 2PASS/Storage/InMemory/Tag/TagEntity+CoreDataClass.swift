// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

@objc(TagEntity)
final class TagEntity: NSManagedObject {
    @nonobjc static let entityName = "TagEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! TagEntity
        
        entity.tagID = tagID
        entity.name = name
        entity.modificationDate = modificationDate
        entity.position = position
        entity.vaultID = vaultID
        entity.color = color?.hexString
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        tagID: ItemTagID,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: UIColor?
    ) {
        guard let entity = getEntity(on: context, tagID: tagID) else {
            Log("Can't find Tag entity for tagID: \(tagID)", module: .storage)
            return
        }
        
        update(
            on: context,
            entity: entity,
            name: name,
            modificationDate: modificationDate,
            position: position,
            vaultID: vaultID,
            color: color?.hexString
        )
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        entity: TagEntity,
        name: String,
        modificationDate: Date,
        position: Int16,
        vaultID: VaultID,
        color: String?
    ) {
        entity.name = name
        entity.modificationDate = modificationDate
        entity.position = position
        entity.vaultID = vaultID
        entity.color = color
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        tagID: ItemTagID
    ) -> TagEntity? {
        let list = listItems(
            on: context,
            options: .tag(tagID)
        )
        return list.first
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        options: TagListOptions
    ) -> [TagEntity] {
        listItems(on: context, predicate: options.predicate, sortDescriptors: options.sortDescriptors)
    }
    
    @nonobjc static func delete(on context: NSManagedObjectContext, entity: TagEntity) {
        Log("Deleting entity of type: \(entity)", module: .storage)
        context.delete(entity)
    }
    
    @nonobjc static func deleteAllTagEntities(on context: NSManagedObjectContext) {
        let items = listItems(on: context, options: .all)
        items.forEach { item in
            context.delete(item)
        }
    }
}

private extension TagEntity {
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]?
    ) -> [TagEntity] {
        let fetchRequest = TagEntity.fetchRequest()
        if let predicate {
            fetchRequest.predicate = predicate
        }
        if let sortDescriptors {
            fetchRequest.sortDescriptors = sortDescriptors
        }
        
        var list: [TagEntity] = []
        
        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("TagEntity in Storage listItems(filter:\(String(describing: predicate)): \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
        
        return list
    }
}
