// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public struct BackupConfigEntry<Config: Codable & Sendable>: Codable, Sendable {
    public let id: BackupConfig.ID
    public let createdAt: Date
    public let config: Config

    public init(id: BackupConfig.ID, createdAt: Date, config: Config) {
        self.id = id
        self.createdAt = createdAt
        self.config = config
    }
}

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

    var iCloudEntry: BackupConfigEntry<BackupiCloudConfig>? {
        for case .iCloud(let entry) in self { return entry }
        return nil
    }

    var hasICloud: Bool {
        iCloudEntry != nil
    }
}
