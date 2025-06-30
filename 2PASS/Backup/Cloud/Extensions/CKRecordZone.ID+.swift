// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CloudKit
import Common

public extension CKRecordZone.ID {
    static func from(vaultID: VaultID) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "TwoPassZone_\(vaultID.uuidString)", ownerName: CKCurrentUserDefaultName)
    }
}
