// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

/// Pairs a registered backup-sync config with its persistent instance id. Used both
/// in-memory (wrapped in `BackupConfig`) and on-disk (inside the encrypted persisted blob).
/// Kind is encoded in the `Config` type parameter, so no kind field is stored alongside.
public struct BackupConfigEntry<Config: Codable & Sendable>: Codable, Sendable {
    public let id: BackupConfig.ID
    /// Set at registration; preserved by updates. Enables sorting across kinds since
    /// per-kind ordering on its own doesn't give a global order.
    public let createdAt: Date
    public let config: Config

    public init(id: BackupConfig.ID, createdAt: Date, config: Config) {
        self.id = id
        self.createdAt = createdAt
        self.config = config
    }
}

/// Kind-discriminated, type-erased counterpart to `BackupConfigEntry<Config>` for callers
/// that handle every kind in one list. `Identifiable` via the inner entry's `id`.
public enum BackupConfig: Sendable, Identifiable, Codable {
    public typealias ID = UUID
    public typealias Service = BackupSyncService

    case webDAV(BackupConfigEntry<BackupWebDAVConfig>)
    case s3(BackupConfigEntry<S3ServiceConfig>)
    case iCloud(BackupConfigEntry<BackupiCloudConfig>)

    public var id: ID {
        switch self {
        case .webDAV(let entry): return entry.id
        case .s3(let entry): return entry.id
        case .iCloud(let entry): return entry.id
        }
    }

    public var service: Service {
        switch self {
        case .webDAV: return .webDAV
        case .s3: return .s3
        case .iCloud: return .iCloud
        }
    }

    public var createdAt: Date {
        switch self {
        case .webDAV(let entry): return entry.createdAt
        case .s3(let entry): return entry.createdAt
        case .iCloud(let entry): return entry.createdAt
        }
    }
}

public extension Array where Element == BackupConfig {
    var webDAVEntries: [BackupConfigEntry<BackupWebDAVConfig>] {
        compactMap {
            if case .webDAV(let entry) = $0 { return entry } else { return nil }
        }
    }

    /// The single iCloud entry, if any. Single-instance is enforced at registration time;
    /// this accessor returns the first hit and ignores duplicates.
    var iCloudEntry: BackupConfigEntry<BackupiCloudConfig>? {
        for case .iCloud(let entry) in self { return entry }
        return nil
    }

    var hasICloud: Bool {
        iCloudEntry != nil
    }
}
