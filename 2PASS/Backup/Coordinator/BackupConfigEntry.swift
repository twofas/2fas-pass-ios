// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Pairs a registered backup-sync config with its persistent instance id.
///
/// Used in two roles:
///   - **In-memory:** appears wrapped in `BackupConfig` cases inside the unified list returned
///     by `BackupSyncContainer.savedConfigs` / `BackupSyncConfigStore.loadConfigs()`.
///   - **On-disk:** the JSON shape inside the encrypted blob the adapter writes through
///     `MainRepository.saveBackupConfigs(_:)`. `Codable` conformance means the same struct
///     serves both ends with no separate wrapper type.
///
/// The kind is encoded in the `Config` type parameter — `BackupConfigEntry<BackupWebDAVConfig>`
/// is unambiguously a WebDAV entry — so storing kind alongside the id would be redundant.
/// `id` is just the `UUID` minted at registration time; consumers that need the discriminator
/// read it from `BackupSynchronizing.kind` on the materialized service.
public struct BackupConfigEntry<Config: Codable & Sendable>: Codable, Sendable {
    public let id: UUID
    /// Wall-clock time the entry was first registered. Set at registration; preserved by
    /// `BackupSyncContainer.update(_:)`. Lets callers sort entries by add-order across kinds —
    /// the per-kind storage lists already preserve order *within* a kind, but a global ordering
    /// requires a comparable field shared between them.
    public let createdAt: Date
    public let config: Config

    public init(id: UUID, createdAt: Date, config: Config) {
        self.id = id
        self.createdAt = createdAt
        self.config = config
    }
}

/// A registered backup config, kind-discriminated. The type-erased counterpart to the generic
/// `BackupConfigEntry<Config>` — use this where callers need to deal with every kind in one
/// homogeneous list (UI lists, "all backends" overviews, global ordering by `createdAt`). Each
/// case preserves the underlying typed entry so consumers can switch to recover the full config.
///
/// `Identifiable` via the inner entry's `id`, so SwiftUI's `ForEach` / `List` work out of the
/// box: `ForEach(interactor.allConfigs) { ... }`.
public enum BackupConfig: Sendable, Identifiable, Codable {
    case webDAV(BackupConfigEntry<BackupWebDAVConfig>)
    case s3(BackupConfigEntry<S3ServiceConfig>)

    public var id: UUID {
        switch self {
        case .webDAV(let entry): return entry.id
        case .s3(let entry): return entry.id
        }
    }

    public var kind: SyncServiceKind {
        switch self {
        case .webDAV: return .webDAV
        case .s3: return .s3
        }
    }

    public var createdAt: Date {
        switch self {
        case .webDAV(let entry): return entry.createdAt
        case .s3(let entry): return entry.createdAt
        }
    }
}

public extension Array where Element == BackupConfig {
    /// All WebDAV entries from this list, registration order preserved.
    var webDAVEntries: [BackupConfigEntry<BackupWebDAVConfig>] {
        compactMap {
            if case .webDAV(let entry) = $0 { return entry } else { return nil }
        }
    }
}
