// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension TagCachedEntity {

    @nonobjc static func fetchRequest() -> NSFetchRequest<TagCachedEntity> {
        return NSFetchRequest<TagCachedEntity>(entityName: entityName)
    }

    @NSManaged var tagID: ItemTagID
    @NSManaged var name: Data
    @NSManaged var modificationDate: Date
    @NSManaged var position: Int16
    @NSManaged var color: String?
    @NSManaged var vaultID: VaultID
    @NSManaged var metadata: Data

}

extension TagCachedEntity : Identifiable {}

extension TagCachedEntity {
    var toData: ItemTagEncryptedData {
        .init(
            tagID: tagID,
            vaultID: vaultID,
            name: name,
            color: color,
            position: Int(position),
            modificationDate: modificationDate
        )
    }
}
