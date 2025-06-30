// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CloudKit

extension TagRecord {
    static func recreate(
        with metadata: Data,
        data: ItemTagEncryptedData
    ) -> CKRecord? {
        recreate(
            with: metadata,
            tagID: data.id,
            name: data.name,
            modificationDate: data.modificationDate,
            position: data.position,
            color: data.color,
            vaultID: data.vaultID
        )
    }
    
    static func create(data: ItemTagEncryptedData) -> CKRecord? {
        create(
            zoneID: .from(vaultID: data.vaultID),
            tagID: data.id,
            name: data.name,
            modificationDate: data.modificationDate,
            position: data.position,
            color: data.color,
            vaultID: data.vaultID
        )
    }
    
    func toRecordData() -> RecordDataTagItem {
        .init(
            tagItem: .init(
                tagID: tagID,
                vaultID: vaultID,
                name: name,
                color: color,
                position: position,
                modificationDate: modificationDate
            ),
            metadata: encodeSystemFields()
        )
    }
}
