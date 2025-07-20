// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct VaultCloudData: Hashable, Identifiable {
    public var id: VaultID {
        vaultID
    }
    
    public let vaultID: VaultID
    public let name: String
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public let metadata: Data
    public private(set) var deviceNames: Data
    public private(set) var deviceID: DeviceID
    public private(set) var schemaVersion: Int
    public private(set) var seedHash: String
    public private(set) var reference: String
    public private(set) var kdfSpec: Data
    
    public init(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: Data,
        deviceID: DeviceID,
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: Data
    ) {
        self.vaultID = vaultID
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.deviceNames = deviceNames
        self.deviceID = deviceID
        self.schemaVersion = schemaVersion
        self.seedHash = seedHash
        self.reference = reference
        self.kdfSpec = kdfSpec
    }
    
    public mutating func update(
        deviceNames: Data,
        deviceID: DeviceID,
        seedHash: String,
        reference: String,
        kdfSpec: Data,
        updatedAt: Date,
        schemaVersion: Int
    ) {
        self.updatedAt = updatedAt
        self.deviceNames = deviceNames
        self.deviceID = deviceID
        self.seedHash = seedHash
        self.reference = reference
        self.kdfSpec = kdfSpec
        self.schemaVersion = schemaVersion
    }
    
    public mutating func update(deviceID: DeviceID, updatedAt: Date) {
        self.deviceID = deviceID
        self.updatedAt = updatedAt
    }
}
