// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Which awaiting-flags the just-completed sync actually honored. Threaded through
/// `setLastSyncDate` so adapters can do conditional (not blanket) clears — otherwise a
/// normal sync that finishes after a flag is set would silently wipe it without acting.
/// Each Bool means "this success path acted on the flag," not "the flag was set."
public struct BackupSyncFlags: Sendable {
    public let overwritingVault: Bool
    public let allowingAnyDeviceId: Bool

    public init(overwritingVault: Bool, allowingAnyDeviceId: Bool) {
        self.overwritingVault = overwritingVault
        self.allowingAnyDeviceId = allowingAnyDeviceId
    }
}

/// Persistence port for per-config last-successful-sync timestamps. Kept separate from
/// `BackupSyncConfigStore` so the configs blob is immutable across sync runs.
public protocol BackupSyncDateStore: Sendable {
    func lastSyncDate(for id: BackupConfig.ID) -> Date?

    /// `consumed` reports which awaiting-flags this success path honored, so the adapter
    /// clears only the flags whose work was actually performed.
    func setLastSyncDate(_ date: Date, for id: BackupConfig.ID, consumed: BackupSyncFlags)
}
