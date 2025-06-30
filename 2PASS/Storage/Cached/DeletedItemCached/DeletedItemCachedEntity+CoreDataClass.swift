// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

@objc(DeletedItemCachedEntity)
final class DeletedItemCachedEntity: NSManagedObject {
    @nonobjc private static let entityName = "DeletedItemCachedEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        vaultID: VaultID,
        metadata: Data
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! DeletedItemCachedEntity
        
        entity.itemID = itemID
        entity.kind = kind.rawValue
        entity.deletedAt = deletedAt
        entity.vaultID = vaultID
        entity.metadata = metadata
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        vaultID: VaultID,
        metadata: Data
    ) {
        guard let entity = getEntity(on: context, itemID: itemID) else {
            Log("Can't find Deleted Item entity for itemID: \(itemID)", module: .storage, severity: .error)
            return
        }
        
        entity.kind = kind.rawValue
        entity.deletedAt = deletedAt
        entity.vaultID = vaultID
        entity.metadata = metadata
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        vaultID: VaultID?,
        limit: Int? = nil
    ) -> [DeletedItemCachedEntity] {
        let fetchRequest = DeletedItemCachedEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(
                key: #keyPath(DeletedItemCachedEntity.deletedAt),
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

        var list: [DeletedItemCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("DeletedItemCachedEntity in Storage listItems: \(err.localizedDescription)", module: .storage, severity: .error)
            // swiftlint:enable line_length
            return []
        }

        return list
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        itemID: DeletedItemID
    ) -> DeletedItemCachedEntity? {
        let fetchRequest = DeletedItemCachedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        fetchRequest.includesPendingChanges = true

        var list: [DeletedItemCachedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("DeletedItemCachedEntity in Storage listItems: \(err.localizedDescription)", module: .storage, severity: .error)
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

    @nonobjc static func delete(on context: NSManagedObjectContext, entity: DeletedItemCachedEntity) {
        Log("Deleting entity of type: DeletedItemCachedEntity", module: .storage, save: false)
        context.delete(entity)
    }
}
