// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CloudKit

public struct VaultRawData: Hashable, Identifiable {
    public var id: VaultID {
        vaultID
    }
    
    public let vaultID: VaultID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let deviceNames: Data
    public let deviceID: DeviceID
    public let schemaVersion: Int
    public let seedHash: String
    public let reference: String
    public let kdfSpec: Data
    public let zoneID: CKRecordZone.ID
    
    public init(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data,
        zoneID: CKRecordZone.ID
    ) {
        self.vaultID = vaultID
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deviceNames = deviceNames
        self.deviceID = deviceID
        self.schemaVersion = schemaVersion
        self.seedHash = seedHash
        self.reference = reference
        self.kdfSpec = kdfSpec
        self.zoneID = zoneID
    }
}
