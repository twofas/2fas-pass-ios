// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public struct RecordDataPassword {
    public let password: PasswordEncryptedData
    public let metadata: Data
    
    public init(password: PasswordEncryptedData, metadata: Data) {
        self.password = password
        self.metadata = metadata
    }
}

public struct RecordDataDeletedItem {
    public let deletedItem: DeletedItemData
    public let metadata: Data
    
    public init(deletedItem: DeletedItemData, metadata: Data) {
        self.deletedItem = deletedItem
        self.metadata = metadata
    }
}

public struct RecordDataTagItem {
    public let tagItem: ItemTagEncryptedData
    public let metadata: Data
    
    public init(tagItem: ItemTagEncryptedData, metadata: Data) {
        self.tagItem = tagItem
        self.metadata = metadata
    }
}

public struct RecordDataVault {
    public struct DeviceName: Codable {
        public let deviceID: DeviceID
        public let deviceName: String
        
        public init(deviceID: DeviceID, deviceName: String) {
            self.deviceID = deviceID
            self.deviceName = deviceName
        }
    }
    
    public let vaultID: VaultID
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let metadata: Data
    public let deviceNames: [DeviceName]
    public let schemaVersion: Int
    public let seedHash: String
    public let reference: String
    public let kdfSpec: KDFSpec
    
    public init(
        vaultID: VaultID,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        metadata: Data,
        deviceNames: [DeviceName],
        schemaVersion: Int,
        seedHash: String,
        reference: String,
        kdfSpec: KDFSpec
    ) {
        self.vaultID = vaultID
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.deviceNames = deviceNames
        self.schemaVersion = schemaVersion
        self.seedHash = seedHash
        self.reference = reference
        self.kdfSpec = kdfSpec
    }
}
