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
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
        let entity = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! VaultEncryptedEntity
        
        entity.vaultID = vaultID
        entity.name = name
        entity.trustedKey = trustedKey
        
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
    }

    @nonobjc static func update(
        on context: NSManagedObjectContext,
        vaultID: VaultID,
        name: String,
        trustedKey: Data,
        createdAt: Date,
        updatedAt: Date
    ) {
    guard let entity = getEntity(on: context, vaultID: vaultID) else {
        Log("VaultEncryptedEntity: Can't find entity for vaultID: \(vaultID)", module: .storage)
            return
        }
        
        entity.name = name
        entity.trustedKey = trustedKey
        
        entity.createdAt = createdAt
        entity.updatedAt = updatedAt
    }
    
    @nonobjc static func getEntity(
        on context: NSManagedObjectContext,
        vaultID: UUID
    ) -> VaultEncryptedEntity? {
        let list = listItems(on: context)

        // If something went wrong (wrong migration, some bugs) -> remove duplicated entries instead of:
        if list.count > 1 {
            Log("VaultEncryptedEntity: Error while fetching entity with VaultID: \(vaultID). There's more than one. Correcting!", severity: .error)
            let itemsForDeletition = list[1...]
            for item in itemsForDeletition {
                delete(on: context, entity: item)
            }
        }

        return list.first
    }

    @nonobjc static func listItems(
        on context: NSManagedObjectContext
    ) -> [VaultEncryptedEntity] {
        let fetchRequest = VaultEncryptedEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(
                key: #keyPath(VaultEncryptedEntity.name),
                ascending: true,
                selector: #selector(NSString.localizedStandardCompare)
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
    
    // MARK: - Passwords
    
    @nonobjc static func deletePassword(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, password: PasswordEncryptedEntity) {
        Log("VaultEncryptedEntity: Deleting entity of type: \(password) in vault: \(vault)", module: .storage)
        vault.removeFromPasswords(password)
    }
    
    @nonobjc static func deletePasswords(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, passwords: [PasswordEncryptedEntity]) {
        Log("VaultEncryptedEntity: Deleting entity of type: \(passwords) in vault: \(vault)", module: .storage)
        vault.removeFromPasswords(Set(passwords))
    }
    
    @nonobjc static func addPassword(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, password: PasswordEncryptedEntity) {
        Log("VaultEncryptedEntity: Adding entity of type: \(password) in vault: \(vault)", module: .storage)
        vault.addToPasswords(password)
    }

    @nonobjc static func addPasswords(on context: NSManagedObjectContext, vault: VaultEncryptedEntity, passwords: [PasswordEncryptedEntity]) {
        Log("VaultEncryptedEntity: Adding entity of type: \(passwords) in vault: \(vault)", module: .storage)
        vault.addToPasswords(Set(passwords))
    }
    
    @nonobjc static func listPasswords(on context: NSManagedObjectContext, vault: VaultEncryptedEntity) -> [PasswordEncryptedEntity] {
        guard let passwords = vault.passwords else {
            return []
        }
        return Array(passwords)
    }
}
