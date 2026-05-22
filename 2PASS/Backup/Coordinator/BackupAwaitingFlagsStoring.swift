// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Persistence port for the per-config "next sync needs special handling" flags.
/// `vaultOverride` is marked after a master-password change (re-push the re-encrypted
/// vault); `deviceRegistration` is marked after recovery (first sync registers this device
/// even without the multi-device entitlement). Clearing happens elsewhere — when the
/// specific sync succeeds — so this port only exposes read + mark.
public protocol BackupAwaitingFlagsStoring: Sendable {
    var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func markVaultOverrideAwaiting(configIDs: Set<BackupConfig.ID>)

    var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func markDeviceRegistrationAwaiting(configIDs: Set<BackupConfig.ID>)
}
