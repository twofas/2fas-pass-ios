// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct BackupIndex: Codable, Equatable, Sendable {
    public let backups: [BackupIndexEntry]

    public init(backups: [BackupIndexEntry]) {
        self.backups = backups
    }
}

extension BackupIndex {
    public func firstIndex(for vaultID: UUID, seedHash: String) -> Int? {
        backups.firstIndex(
            where: { UUID(uuidString: $0.vaultId) == vaultID && $0.seedHashHex.lowercased() == seedHash.lowercased() }
        )
    }
}

public struct BackupIndexEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { vaultId }

    public let seedHashHex: String
    public let vaultId: String
    public let vaultCreatedAt: Int
    public var vaultUpdatedAt: Int
    public var deviceName: String
    public let deviceId: UUID
    public let schemaVersion: Int

    public init(
        seedHashHex: String,
        vaultId: String,
        vaultCreatedAt: Int,
        vaultUpdatedAt: Int,
        deviceName: String,
        deviceId: UUID,
        schemaVersion: Int
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
