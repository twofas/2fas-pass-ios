// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Persistence port for per-config "last successful sync" timestamps.
///
/// Deliberately separate from `BackupSyncConfigStore`: configs describe the registered backend
/// (URL, credentials, kind), while these timestamps are runtime sync-state. Splitting the ports
/// keeps the configs blob immutable across sync runs — only the timestamp slot gets written when
/// a sync succeeds.
///
/// `BackupFileSyncSession` writes through this port the moment its own `performSync` returns
/// success. UI consumers read via `BackupSyncConfigsInteracting.lastSyncDate(for:)`.
public protocol BackupSyncDateStore: Sendable {
    /// The most recent successful sync timestamp for `id`, or `nil` if no successful sync has
    /// ever been recorded.
    func lastSyncDate(for id: UUID) -> Date?

    /// Records that a sync for `id` succeeded at `date`. Overwrites any previous value.
    func setLastSyncDate(_ date: Date, for id: UUID)
}
