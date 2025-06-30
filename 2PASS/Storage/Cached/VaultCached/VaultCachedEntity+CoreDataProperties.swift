// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData
import Common

extension VaultCachedEntity {
    @nonobjc static func fetchRequest() -> NSFetchRequest<VaultCachedEntity> {
        NSFetchRequest<VaultCachedEntity>(entityName: "VaultCachedEntity")
    }

    @NSManaged var vaultID: VaultID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var metadata: Data
    @NSManaged var deviceNames: Data
    @NSManaged var deviceID: DeviceID
    @NSManaged var schemaVersion: Int
    @NSManaged var seedHash: String
    @NSManaged var reference: String
    @NSManaged var kdfSpec: Data
}

extension VaultCachedEntity: Identifiable {}

extension VaultCachedEntity {
    func toData() -> VaultCloudData {
        VaultCloudData(
            vaultID: vaultID,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            deviceNames: deviceNames,
            deviceID: deviceID,
            schemaVersion: schemaVersion,
            seedHash: seedHash,
            reference: reference,
            kdfSpec: kdfSpec
        )
    }
}
