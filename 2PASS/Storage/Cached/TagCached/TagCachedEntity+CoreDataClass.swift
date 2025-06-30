// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(TagCachedEntity)
final class TagCachedEntity: NSManagedObject {
    @nonobjc static let entityName = "TagCachedEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID,
        metadata: Data
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! TagCachedEntity
        
        entity.tagID = tagID
        entity.name = name
        entity.color = color
        entity.position = position
        entity.modificationDate = modificationDate
        entity.vaultID = vaultID
        entity.metadata = metadata
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        tagID: ItemTagID,
        name: Data,
        color: String?,
        position: Int16,
        modificationDate: Date,
        vaultID: VaultID,
        metadata: Data
    ) {
        guard let entity = getEntity(on: context, tagID: tagID) else {
            Log("Can't find Tag entity for tagID: \(tagID)", module: .storage, severity: .error)
            return
        }
        
        entity.name = name
        entity.color = color
        entity.position = position
        entity.modificationDate = modificationDate
        entity.vaultID = vaultID
        entity.metadata = metadata
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        vaultID: UUID?,
        limit: Int? = nil
    ) -> [TagCachedEntity] {
        let fetchRequest = TagCachedEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(
                key: #keyPath(TagCachedEntity.position),
                ascending: true
            ),
            NSSortDescriptor(
                key: #keyPath(TagCachedEntity.modificationDate),
                ascending: false,
                selector: #selector(NSDate.compare)
            )
        ]
        fetchRequest.includesPendingChanges = true
        
        if let vaultID {
            fetchRequest.predicate = NSPredicate(format: "vaultID == %@", vaultID as CVarArg)
        }
        
        if let limit {
            fetchRequest.fetchLimit = limit
        }

        var list: [TagCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("TagCachedEntity in Storage listItems: \(err.localizedDescription)", module: .storage, severity: .error)
            // swiftlint:enable line_length
            return []
        }

        return list
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        tagID: ItemTagID
    ) -> TagCachedEntity? {
        let fetchRequest = TagCachedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "tagID == %@", tagID as CVarArg)
        fetchRequest.includesPendingChanges = true

        var list: [TagCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("TagCachedEntity in Storage getEntity: \(err.localizedDescription)", module: .storage, severity: .error)
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

    @nonobjc static func delete(on context: NSManagedObjectContext, entity: TagCachedEntity) {
        Log("Deleting entity of type: TagCachedEntity", module: .storage, save: false)
        context.delete(entity)
    }
}
