// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Read + mark only — flags are cleared by `BackupSyncDateStore.setLastSyncDate` when the
/// sync that honored them succeeds. `vaultOverride` follows master-password change;
/// `deviceRegistration` follows recovery.
public protocol BackupAwaitingFlagsStoring: Sendable {
    var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func markVaultOverrideAwaiting(configIDs: Set<BackupConfig.ID>)

    var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func markDeviceRegistrationAwaiting(configIDs: Set<BackupConfig.ID>)
}
