// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Each Bool means "this success path acted on the flag," not "the flag was set" —
/// adapters use it to clear only flags whose work actually ran, so a normal sync that
/// finishes after a flag was marked doesn't silently wipe it.
public struct BackupSyncFlags: Sendable {
    public let overwritingVault: Bool
    public let allowingAnyDeviceId: Bool

    public init(overwritingVault: Bool, allowingAnyDeviceId: Bool) {
        self.overwritingVault = overwritingVault
        self.allowingAnyDeviceId = allowingAnyDeviceId
    }
}

/// Separate from `BackupSyncConfigStore` so the configs blob isn't rewritten on every sync.
public protocol BackupSyncDateStore: Sendable {
    func lastSyncDate(for id: BackupConfig.ID) -> Date?

    func setLastSyncDate(_ date: Date, for id: BackupConfig.ID, consumed: BackupSyncFlags)
}
