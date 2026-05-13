// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Snapshot of which "next sync needs special handling" flags the just-completed sync
/// actually honored. Threaded through `setLastSyncDate(_:for:consumed:)` so the adapter
/// implementation can do *conditional* clears of the corresponding awaiting-sets — without
/// it, a normal sync that finishes after the trigger flag was set would silently wipe the
/// flag without having honored it.
///
/// Each Bool is "did this success path act on the flag" (NOT "is the flag currently set").
/// For example, `overwritingVault == true` means "we just uploaded an overwrite; the
/// override-awaiting entry for this id can be cleared." A normal sync passes `false` and
/// the adapter leaves the flag alone.
public struct BackupSyncFlags: Sendable {
    public let overwritingVault: Bool
    public let allowingAnyDeviceId: Bool

    public init(overwritingVault: Bool, allowingAnyDeviceId: Bool) {
        self.overwritingVault = overwritingVault
        self.allowingAnyDeviceId = allowingAnyDeviceId
    }
}

/// Persistence port for per-config "last successful sync" timestamps.
///
/// Deliberately separate from `BackupSyncConfigStore`: configs describe the registered backend
/// (URL, credentials, kind), while these timestamps are runtime sync-state. Splitting the ports
/// keeps the configs blob immutable across sync runs — only the timestamp slot gets written when
/// a sync succeeds.
///
/// `BackupFileSyncSession` and `CloudSyncAdapter` write through this port the moment their own
/// `performSync` returns success. UI consumers read via `BackupSyncConfigsInteracting.lastSyncDate(for:)`.
public protocol BackupSyncDateStore: Sendable {
    /// The most recent successful sync timestamp for `id`, or `nil` if no successful sync has
    /// ever been recorded.
    func lastSyncDate(for id: BackupConfig.ID) -> Date?

    /// Records that a sync for `id` succeeded at `date`. Overwrites any previous value.
    /// `consumed` reports which "next sync needs X" flags this success path actually honored,
    /// so the adapter can clear only the flags whose work was actually performed (instead of
    /// unconditionally clearing on every success — which would lose flags marked mid-sync).
    func setLastSyncDate(_ date: Date, for id: BackupConfig.ID, consumed: BackupSyncFlags)
}
