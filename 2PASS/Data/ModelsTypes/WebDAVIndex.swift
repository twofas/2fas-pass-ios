// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public struct WebDAVIndex: Codable, Equatable {
    public let backups: [WebDAVIndexEntry]
}

extension WebDAVIndex {
    func firstIndex(for vid: UUID, seedHash: String) -> Int? {
        backups.firstIndex(
            where: { UUID(uuidString: $0.vaultId) == vid && $0.seedHashHex.lowercased() == seedHash.lowercased() }
        )
    }
}

public struct WebDAVIndexEntry: Codable, Identifiable, Equatable, Hashable {
    public var id: String {
        vaultId
    }
    
    public let seedHashHex: String
    public let vaultId: String
    public let vaultCreatedAt: Int
    public var vaultUpdatedAt: Int
    public let deviceName: String
    public let deviceId: UUID
    public let schemaVersion: Int
    
    init(
        seedHashHex: String,
        vaultId: String,
        vaultCreatedAt: Int,
        vaultUpdatedAt: Int,
        deviceName: String,
        deviceId: UUID,
        schemaVersion: Int = Config.indexSchemaVersion
    ) {
        self.seedHashHex = seedHashHex
        self.vaultId = vaultId
        self.vaultCreatedAt = vaultCreatedAt
        self.vaultUpdatedAt = vaultUpdatedAt
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.schemaVersion = schemaVersion
    }
}
