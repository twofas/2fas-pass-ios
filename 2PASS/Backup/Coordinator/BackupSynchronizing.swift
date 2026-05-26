// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol BackupSynchronizing: Sendable {
    var id: BackupConfig.ID { get }
    var kind: BackupSyncService { get }
    /// `allowingAnyDeviceId: true` is the recovery override — bypasses the device-id gate
    /// in the local merge. Routine syncs always pass `false`.
    func performSync(overwritingVault: Bool, allowingAnyDeviceId: Bool) async throws(BackupSyncError) -> BackupSyncOutcome
}
