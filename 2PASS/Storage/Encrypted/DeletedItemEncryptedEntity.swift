// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension DeletedItemEncryptedEntity {
    @nonobjc static let entityName = "DeletedItemEncryptedEntity"
    @nonobjc static func fetchRequest() -> NSFetchRequest<DeletedItemEncryptedEntity> {
        NSFetchRequest<DeletedItemEncryptedEntity>(entityName: entityName)
    }
    
    @NSManaged var itemID: DeletedItemID
    @NSManaged var deletedAt: Date
    @NSManaged var kind: String
    @NSManaged var vaultID: VaultID
}

extension DeletedItemEncryptedEntity : Identifiable {}

final class DeletedItemEncryptedEntity: NSManagedObject {
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        vaultID: VaultID
    ) {
        let entity = DeletedItemEncryptedEntity(context: context)
        entity.itemID = itemID
        entity.kind = kind.rawValue
        entity.deletedAt = deletedAt
        entity.vaultID = vaultID
    }
    
    @nonobjc static func update(
        on context: NSManagedObjectContext,
        itemID: DeletedItemID,
        kind: DeletedItemData.Kind,
        deletedAt: Date,
        vaultID: VaultID
    ) {
        guard let entity = getEntity(on: context, itemID: itemID) else {
            Log("Can't find Deleted Password entity for itemID: \(itemID)", module: .storage, severity: .error)
            return
        }
        
        entity.itemID = itemID
        entity.kind = kind.rawValue
        entity.deletedAt = deletedAt
        entity.vaultID = vaultID
    }
    
    @nonobjc static func listItems(
        on context: NSManagedObjectContext,
        vaultID: VaultID,
        limit: Int? = nil
    ) -> [DeletedItemEncryptedEntity] {
        let fetchRequest = DeletedItemEncryptedEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(
                key: #keyPath(DeletedItemEncryptedEntity.deletedAt),
                ascending: false,
                selector: #selector(NSDate.compare)
            )
        ]
        
        fetchRequest.predicate = NSPredicate(format: "vaultID == %@", vaultID as CVarArg)
        
        if let limit {
            fetchRequest.fetchLimit = limit
        }

        var list: [DeletedItemEncryptedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("DeletedItemEncryptedEntity in Storage listItems: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }

        return list
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        itemID: DeletedItemID
    ) -> DeletedItemEncryptedEntity? {
        let fetchRequest = DeletedItemEncryptedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "itemID == %@", itemID as CVarArg)
        fetchRequest.includesPendingChanges = true

        var list: [DeletedItemEncryptedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("DeletedItemEncryptedEntity in Storage listItems: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return nil
        }

        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            Log("DeletedItemEncryptedEntity: Error while fetching entity with ItemID: \(itemID). There's more than one. Correcting!", severity: .error)
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }

        return list.first
    }

    @nonobjc static func delete(on context: NSManagedObjectContext, entity: DeletedItemEncryptedEntity) {
        Log("Deleting entity of type: \(entity)", module: .storage)
        context.delete(entity)
    }
}

extension DeletedItemEncryptedEntity {
    var toData: DeletedItemData {
        .init(
            itemID: itemID,
            vaultID: vaultID,
            kind: DeletedItemData.Kind(rawValue: kind) ?? .login,
            deletedAt: deletedAt
        )
    }
}
