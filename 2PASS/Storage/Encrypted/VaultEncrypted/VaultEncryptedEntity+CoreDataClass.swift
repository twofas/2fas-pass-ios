// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

final class VaultEncryptedEntity: NSManagedObject {
    @nonobjc private static let entityName = "VaultEncryptedEntity"
    
    @nonobjc static func create(
        on context: NSManagedObjectContext,
        vaultID: VaultID,
        name: Data,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date,
        color: String?,
        icon: String?
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! VaultEncryptedEntity

        entity.vaultID = vaultID
        entity.name = name
        entity.trustedKey = trustedKey

        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.color = color
        entity.icon = icon
    }

    @nonobjc static func update(
        on context: NSManagedObjectContext,
        vaultID: VaultID,
        name: Data,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date,
        color: String?,
        icon: String?
    ) {
    guard let entity = getEntity(on: context, vaultID: vaultID) else {
        Log("VaultEncryptedEntity: Can't find entity for vaultID: \(vaultID)", module: .storage)
            return
        }

        entity.name = name
        entity.trustedKey = trustedKey

        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
        entity.color = color
        entity.icon = icon
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        vaultID: UUID
    ) -> VaultEncryptedEntity? {
        let fetchRequest = VaultEncryptedEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "vaultID == %@", vaultID as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            let err = error as NSError
            Log(
                "VaultEncryptedEntity: Error fetching entity with vaultID \(vaultID): \(err.localizedDescription)",
                module: .storage,
                severity: .error
            )
            return nil
        }
    }

    @nonobjc static func listItems(
        on context: NSManagedObjectContext
    ) -> [VaultEncryptedEntity] {
        let fetchRequest = VaultEncryptedEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(
                key: #keyPath(VaultEncryptedEntity.createdAt),
                ascending: true
            )
        ]

        var list: [VaultEncryptedEntity] = []

        do {
            list = try context.fetch(fetchRequest)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("VaultEncryptedEntity in Storage listItems: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }

        return list
    }

    @nonobjc static func delete(on context: NSManagedObjectContext, entity: VaultEncryptedEntity) {
        Log("VaultEncryptedEntity: Deleting entity of type: \(entity)", module: .storage)
        context.delete(entity)
    }
    
    // MARK: - Items
    
    @nonobjc static func deleteItem(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, item: ItemEncryptedEntity) {
        Log("VaultEncryptedEntity: Deleting entity of type: \(item) in vault: \(vault)", module: .storage)
        vault.removeFromItems(item)
    }
    
    @nonobjc static func deleteItems(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, items: [ItemEncryptedEntity]) {
        Log("VaultEncryptedEntity: Deleting entity of type: \(items) in vault: \(vault)", module: .storage)
        vault.removeFromItems(Set(items))
    }
    
    @nonobjc static func addItem(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, item: ItemEncryptedEntity) {
        Log("VaultEncryptedEntity: Adding entity of type: \(item) in vault: \(vault)", module: .storage)
        vault.addToItems(item)
    }

    @nonobjc static func addItems(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, items: [ItemEncryptedEntity]) {
        Log("VaultEncryptedEntity: Adding entity of type: \(items) in vault: \(vault)", module: .storage)
        vault.addToItems(Set(items))
    }
    
    @nonobjc static func listItems(on context: NSManagedObjectContext, vault: VaultEncryptedEntity) -> [ItemEncryptedEntity] {
        guard let items = vault.items else {
            return []
        }
        return Array(items)
    }
}
