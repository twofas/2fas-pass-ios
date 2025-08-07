// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

extension ItemEncryptedEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<ItemEncryptedEntity> {
        NSFetchRequest<ItemEncryptedEntity>(entityName: "ItemEncryptedEntity")
    }
    
    @NSManaged var itemID: PasswordID
    
    @NSManaged var contentVersion: Int16
    @NSManaged var contentType: String
    @NSManaged var content: Data
    
    @NSManaged var creationDate: Date
    @NSManaged var modificationDate: Date
    
    @NSManaged var isTrashed: Bool
    @NSManaged var trashingDate: Date?
    
    @NSManaged var level: String
    @NSManaged var tagIds: [ItemTagID]?
    
    @NSManaged var vault: VaultEncryptedEntity
}

extension ItemEncryptedEntity: Identifiable {}

extension ItemEncryptedEntity {
    func toData() -> ItemEncryptedData {
        ItemEncryptedData(
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: {
                if isTrashed, let trashingDate {
                    return ItemTrashedStatus.yes(trashingDate: trashingDate)
                }
                return .no
            }(),
            protectionLevel: ItemProtectionLevel(level: level),
            contentType: ItemContentType(rawValue: contentType)!,
            contentVersion: Int(contentVersion),
            content: content,
            vaultID: vault.vaultID,
            tagIds: tagIds
        )
    }
}
