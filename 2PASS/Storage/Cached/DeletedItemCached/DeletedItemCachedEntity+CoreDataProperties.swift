// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension DeletedItemCachedEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<DeletedItemCachedEntity> {
        NSFetchRequest<DeletedItemCachedEntity>(entityName: "DeletedItemCachedEntity")
    }

    @NSManaged var itemID: DeletedItemID
    @NSManaged var kind: String
    @NSManaged var deletedAt: Date
    @NSManaged var vaultID: VaultID
    @NSManaged var metadata: Data
}

extension DeletedItemCachedEntity: Identifiable {}

extension DeletedItemCachedEntity {
    var toData: DeletedItemData {
        .init(
            itemID: itemID,
            vaultID: vaultID,
            kind: DeletedItemData.Kind(rawValue: kind) ?? .login,
            deletedAt: deletedAt
        )
    }
}
