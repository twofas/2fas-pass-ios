// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol BackupSynchronizing: Sendable {
    /// Stable per-instance id; matches the id stored in the corresponding `BackupConfigEntry`.
    var id: BackupConfig.ID { get }
    /// Backend discriminator; redundant with the entry's `Config` type parameter on disk, but
    /// needed at runtime since the coordinator works with `[any BackupSynchronizing]`.
    var kind: SyncServiceKind { get }
    /// `allowingAnyDeviceId` is the recovery override — when true, the local merge tolerates a
    /// vault belonging to a different device id even without the multi-device entitlement. Only
    /// recovery flows pass `true`; routine syncs always pass `false`.
    func performSync(overwritingVault: Bool, allowingAnyDeviceId: Bool) async throws(BackupSyncError) -> BackupSyncOutcome
}
