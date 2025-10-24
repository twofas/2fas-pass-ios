// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension ItemMetadataEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<ItemMetadataEntity> {
        NSFetchRequest<ItemMetadataEntity>(entityName: entityName)
    }
    
    @NSManaged var itemID: ItemID

    @NSManaged var creationDate: Date
    @NSManaged var modificationDate: Date

    @NSManaged var isTrashed: Bool
    @NSManaged var trashingDate: Date?
    
    @NSManaged var level: String
    @NSManaged var tagIds: [ItemTagID]?
    
    @NSManaged var name: String?
    
    @NSManaged var contentType: String
    @NSManaged var contentVersion: Int16
}

extension ItemMetadataEntity: Identifiable {}

extension ItemMetadataEntity {
    
    func toMetadata() -> ItemMetadata {
        ItemMetadata(
            creationDate: creationDate,
            modificationDate: modificationDate,
            protectionLevel: ItemProtectionLevel(level: level),
            trashedStatus: {
                if isTrashed, let trashingDate {
                    return .yes(trashingDate: trashingDate)
                }
                return .no
            }(),
            tagIds: tagIds
        )
    }
}
