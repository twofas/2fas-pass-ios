// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Persistence port for the per-config "next sync needs special handling" flags. Two
/// independent `Set<BackupConfig.ID>` slots, both populated externally and consumed by
/// `BackupSyncContainer` to decorate the next sync with `overwritingVault` /
/// `allowingAnyDeviceId` for the matching ids.
///
/// `vaultOverrideAwaitingConfigIDs` is set after a master-password change so every file
/// backend re-pushes the freshly re-encrypted vault; `deviceRegistrationAwaitingConfigIDs`
/// is set after recovery so the first sync can register this device's id even on a
/// non-multi-device entitlement. Each id is cleared independently when its specific sync
/// succeeds — that clearing path lives outside this protocol (in the adapter that observes
/// session success) and reads the same backing store, so this port intentionally exposes
/// only read + mark.
public protocol BackupAwaitingFlagsStoring: Sendable {
    var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func markVaultOverrideAwaiting(configIDs: Set<BackupConfig.ID>)

    var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func markDeviceRegistrationAwaiting(configIDs: Set<BackupConfig.ID>)
}
