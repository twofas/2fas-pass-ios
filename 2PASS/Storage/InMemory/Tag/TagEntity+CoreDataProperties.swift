// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

extension TagEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<TagEntity> {
        NSFetchRequest<TagEntity>(entityName: entityName)
    }

    @NSManaged var tagID: ItemTagID
    @NSManaged var name: String
    @NSManaged var modificationDate: Date
    @NSManaged var position: Int16
    @NSManaged var vaultID: VaultID
    @NSManaged var color: String?

}

extension TagEntity: Identifiable {}

extension TagEntity {
    func toData() -> ItemTagData {
        .init(
            tagID: tagID,
            vaultID: vaultID,
            name: name,
            color:  UIColor(hexString: color),
            position: Int(position),
            modificationDate: modificationDate
        )
    }
}
