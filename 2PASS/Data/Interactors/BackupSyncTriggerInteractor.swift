// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

/// User-driven sync trigger entry points ("Sync now" buttons, per-row sync), plus read access
/// to the per-config last-success timestamps that those triggers produce. Reads the installed
/// `BackupSyncContainer` off `MainRepository` and forwards. Lives apart from
/// `BackupSyncConfigsInteracting` so that callers needing only CRUD on configs don't transitively
/// depend on the orchestration surface — and vice versa.
///
/// `lastSyncDate(for:)` is on this protocol because the timestamp is an *output* of sync runs
/// (written by `BackupFileSyncSession` on success via the `BackupSyncDateStore` adapter) rather
/// than an input to the config CRUD surface.
///
/// All trigger entry points are no-ops when the container hasn't been installed yet
/// (`backupSyncSetupInteractor().initialize()` must have run first). The container is the optional
/// piece; the configs themselves are persisted in `MainRepository` and outlive any container
/// lifecycle.
public protocol BackupSyncTriggerInteracting: AnyObject {
    /// Live app-wide backup sync activity snapshot.
    var currentActivity: BackupSyncActivity { get }

    /// Set of backup-config IDs that should overwrite their remote on the next sync. Populated
    /// per-config (not as a single global Bool) so that with multiple file-based backends —
    /// e.g. two WebDAV servers and an S3 bucket — every one re-pushes the freshly re-encrypted
    /// vault after a master-password change, not just whichever one syncs first. Each entry is
    /// removed independently when its specific config syncs successfully.
    var vaultOverrideAwaitingConfigIDs: Set<UUID> { get }
    func markVaultOverrideAwaiting(configIDs: Set<UUID>)
    func clearVaultOverrideAwaiting(configID: UUID)

    /// Set of backup-config IDs that need `allowingAnyDeviceId: true` on their next sync.
    /// Mirrors the `vaultOverrideAwaitingConfigIDs` shape but addresses a different problem:
    /// after recovery, the local device hasn't yet written its `deviceID` into the WebDAV
    /// index. Until that first sync succeeds, routine syncs (which pass `false` for
    /// `allowingAnyDeviceId`) would trip the multi-device-id gate. The trigger interactor's
    /// sync paths OR the caller's parameter with this set, so a failed first attempt
    /// auto-retries with the override on every subsequent sync until success.
    var deviceRegistrationAwaitingConfigIDs: Set<UUID> { get }
    func markDeviceRegistrationAwaiting(configIDs: Set<UUID>)

    /// Runs every registered backend through the convergence loop. No-op if no container.
    ///
    /// Reads `vaultOverrideAwaitingConfigIDs` and forwards a per-service `overwritingVault`
    /// resolver to the container, so callers don't manage the flag themselves — they call
    /// `syncAll(...)` and the interactor decides per-config whether the run overwrites or
    /// merges.
    ///
    /// `onEvent` (optional) receives per-service `started`/`finished` lifecycle events so the UI
    /// can reflect the coordinator's serial execution row-by-row instead of a global flag.
    /// Events fire from the coordinator actor; consumers running on the main actor must hop
    /// themselves (e.g. via `Task { @MainActor in ... }`).
    func syncAll(onEvent: BackupSyncSession.ProgressHandler?)

    /// Runs only the backend with the given id through the coordinator. No-op if no entry
    /// matches or the container hasn't been installed yet.
    ///
    /// `allowingAnyDeviceId` is the recovery override — pass `true` when driving the recovery
    /// flow, which needs to merge a vault belonging to a different device id even without the
    /// multi-device entitlement. Routine syncs always pass `false`.
    func sync(
        id: UUID,
        overwritingVault: Bool,
        allowingAnyDeviceId: Bool,
        onEvent: BackupSyncSession.ProgressHandler?
    ) async -> Result<BackupSyncOutcome, BackupSyncError>?

    /// Most recent successful sync timestamp for `id`, or `nil` if no successful sync recorded.
    /// Reads through to the persistent date store; intended for UI display ("Last synced …").
    func lastSyncDate(for id: UUID) -> Date?

    /// Cancels the currently running backup sync session, if any.
    func cancelCurrentSync()
}

public extension BackupSyncTriggerInteracting {
    func syncAll() { syncAll(onEvent: nil) }
    func sync(id: UUID) async { _ = await sync(id: id, overwritingVault: false, allowingAnyDeviceId: false, onEvent: nil) }
    func sync(id: UUID, onEvent: BackupSyncSession.ProgressHandler?) async {
        _ = await sync(id: id, overwritingVault: false, allowingAnyDeviceId: false, onEvent: onEvent)
    }
}

final class BackupSyncTriggerInteractor: BackupSyncTriggerInteracting {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }

    var currentActivity: BackupSyncActivity {
        mainRepository.backupSyncContainer.currentActivity
    }

    var vaultOverrideAwaitingConfigIDs: Set<UUID> {
        mainRepository.vaultOverrideAwaitingConfigIDs
    }

    func markVaultOverrideAwaiting(configIDs: Set<UUID>) {
        mainRepository.markVaultOverrideAwaiting(configIDs: configIDs)
    }

    func clearVaultOverrideAwaiting(configID: UUID) {
        mainRepository.clearVaultOverrideAwaiting(configID: configID)
    }

    var deviceRegistrationAwaitingConfigIDs: Set<UUID> {
        mainRepository.deviceRegistrationAwaitingConfigIDs
    }

    func markDeviceRegistrationAwaiting(configIDs: Set<UUID>) {
        mainRepository.markDeviceRegistrationAwaiting(configIDs: configIDs)
    }

    func syncAll(onEvent: BackupSyncSession.ProgressHandler?) {
        // Snapshot both awaiting sets once and capture them in per-service resolvers — that
        // way the closures stay Sendable and a clear-while-running sequence (entries removed
        // by `BackupSyncAdapter.setLastSyncDate` as services finish) doesn't make a
        // still-running peer suddenly lose its flag mid-pass.
        let overrideAwaiting = vaultOverrideAwaitingConfigIDs
        let registrationAwaiting = deviceRegistrationAwaitingConfigIDs
        mainRepository.backupSyncContainer.syncAll(
            overwritingVault: { configID in overrideAwaiting.contains(configID) },
            allowingAnyDeviceId: { configID in registrationAwaiting.contains(configID) },
            onEvent: onEvent
        )
    }

    func sync(
        id: UUID,
        overwritingVault: Bool,
        allowingAnyDeviceId: Bool,
        onEvent: BackupSyncSession.ProgressHandler?
    ) async -> Result<BackupSyncOutcome, BackupSyncError>? {
        // OR the caller's parameter with the persistent flag — recovery flows still pass
        // `true` directly for the immediate post-import sync; subsequent retries (where the
        // caller passes `false`) auto-pick up the flag-driven override until that config's
        // first successful sync clears it via `BackupSyncAdapter.setLastSyncDate`.
        let needsRegistration = mainRepository.deviceRegistrationAwaitingConfigIDs.contains(id)
        return await mainRepository.backupSyncContainer.sync(
            id,
            overwritingVault: overwritingVault,
            allowingAnyDeviceId: allowingAnyDeviceId || needsRegistration,
            onEvent: onEvent
        )
    }

    func lastSyncDate(for id: UUID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    func cancelCurrentSync() {
        mainRepository.backupSyncContainer.cancelCurrentSync()
    }
}
