// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CloudKit

extension DeletedItemRecord {
    static func recreate(
        with metadata: Data,
        data: DeletedItemData
    ) -> CKRecord? {
        recreate(
            with: metadata,
            itemID: data.itemID,
            kind: data.kind,
            vaultID: data.vaultID,
            deletedAt: data.deletedAt
        )
    }
    
    static func create(data: DeletedItemData) -> CKRecord? {
        create(
            zoneID: .from(vaultID: data.vaultID),
            itemID: data.itemID,
            kind: data.kind,
            vaultID: data.vaultID,
            deletedAt: data.deletedAt
        )
    }
    
    func toRecordData() -> RecordDataDeletedItem {
        .init(
            deletedItem: .init(itemID: itemID, vaultID: vaultID, kind: kind, deletedAt: deletedAt),
            metadata: encodeSystemFields()
        )
    }
}
