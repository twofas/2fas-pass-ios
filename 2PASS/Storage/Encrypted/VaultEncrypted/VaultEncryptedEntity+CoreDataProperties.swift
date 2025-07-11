// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension VaultEncryptedEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<VaultEncryptedEntity> {
        NSFetchRequest<VaultEncryptedEntity>(entityName: "VaultEncryptedEntity")
    }

    @NSManaged var vaultID: VaultID
    @NSManaged var name: String
    @NSManaged var trustedKey: Data
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var items: Set<ItemEncryptedEntity>?
    @NSManaged var passwords: Set<PasswordEncryptedEntity>?
}

// MARK: Generated accessors for passwords
extension VaultEncryptedEntity {
    @objc(addPasswordsObject:)
    @NSManaged func addToPasswords(_ value: PasswordEncryptedEntity)

    @objc(removePasswordsObject:)
    @NSManaged func removeFromPasswords(_ value: PasswordEncryptedEntity)

    @objc(addPasswords:)
    @NSManaged func addToPasswords(_ values: Set<PasswordEncryptedEntity>)

    @objc(removePasswords:)
    @NSManaged func removeFromPasswords(_ values: Set<PasswordEncryptedEntity>)
    
    @objc(addItemsObject:)
    @NSManaged func addToItems(_ value: ItemEncryptedEntity)

    @objc(removeItemsObject:)
    @NSManaged func removeFromItems(_ value: ItemEncryptedEntity)

    @objc(addItems:)
    @NSManaged func addToItems(_ values: Set<ItemEncryptedEntity>)

    @objc(removeItems:)
    @NSManaged func removeFromItems(_ values: Set<ItemEncryptedEntity>)
}

extension VaultEncryptedEntity: Identifiable {}

extension VaultEncryptedEntity {
    func toData() -> VaultEncryptedData {
        VaultEncryptedData(
            vaultID: vaultID,
            name: name,
            trustedKey: trustedKey,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isEmpty: items?.isEmpty ?? true
        )
    }
}
