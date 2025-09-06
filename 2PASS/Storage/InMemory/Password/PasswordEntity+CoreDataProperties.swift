// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension PasswordEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<PasswordEntity> {
        NSFetchRequest<PasswordEntity>(entityName: entityName)
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
    @NSManaged var contentData: Data
}

extension PasswordEntity: Identifiable {}

extension PasswordEntity {
    
    func toData() -> RawItemData {
        let metadata = ItemMetadata(
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
        
        let contentType = ItemContentType(rawValue: contentType)
        
        return .init(
            id: itemID,
            metadata: metadata,
            name: name,
            contentType: contentType,
            contentVersion: Int(contentVersion),
            content: contentData
        )
    }
}
