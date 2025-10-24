// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension ItemCachedEntity {
    @nonobjc static let entityName = "ItemCachedEntity"

    @nonobjc static func fetchRequest() -> NSFetchRequest<ItemCachedEntity> {
        return NSFetchRequest<ItemCachedEntity>(entityName: entityName)
    }

    @NSManaged var itemID: ItemID
    @NSManaged var content: Data
    @NSManaged var contentType: String
    @NSManaged var contentVersion: Int16
    @NSManaged var creationDate: Date
    @NSManaged var modificationDate: Date
    @NSManaged var isTrashed: Bool
    @NSManaged var trashingDate: Date?
    @NSManaged var protectionLevel: String
    @NSManaged var tagIds: [ItemTagID]?
    @NSManaged var vaultID: UUID
    @NSManaged var metadata: Data
}

extension ItemCachedEntity : Identifiable {}

extension ItemCachedEntity {
    func toData() -> ItemEncryptedData {
        .init(
            itemID: itemID,
            creationDate: creationDate,
            modificationDate: modificationDate,
            trashedStatus: {
                if isTrashed, let trashingDate {
                    return ItemTrashedStatus.yes(trashingDate: trashingDate)
                }
                return .no
            }(),
            protectionLevel: ItemProtectionLevel(level: protectionLevel),
            contentType: .init(rawValue: contentType),
            contentVersion: Int(contentVersion),
            content: content,
            vaultID: vaultID,
            tagIds: tagIds
        )
    }
}
