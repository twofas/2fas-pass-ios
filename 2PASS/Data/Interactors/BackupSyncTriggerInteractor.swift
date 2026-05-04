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

    /// Marks every currently-registered backend for vault overwrite on its next sync. Used
    /// by the password-change flow. The container resolves the id set internally — callers
    /// don't enumerate configs. Each backend's `performSync` decides per-kind whether to
    /// honor the flag, and `BackupSyncAdapter` clears each id only when the matching sync
    /// reported `consumed.overwritingVault`, so flagging a kind that ignores the override
    /// is harmless.
    func markAllServicesAwaitingVaultOverride()

    /// Marks the supplied config id for `allowingAnyDeviceId: true` on its next sync.
    /// Used by the recovery flow on the specific config it just added. The first
    /// successful sync clears the entry; any failed-and-retried sync in between still
    /// honors the flag because it persists across attempts.
    func markAwaitingDeviceRegistration(configID: UUID)

    /// Fire-and-forget: triggers a sync at background priority and returns immediately. Use
    /// this from non-async post-mutation sites ("user changed something, propagate to
    /// backups when convenient") — internally spawns a detached `.utility`-priority task in
    /// the container. Cancellation is via `cancelCurrentSync()`.
    func syncAll()

    /// Awaitable variant — runs every registered backend through the convergence loop and
    /// returns each service's `BackupSyncSession.SyncResult` from the final pass. Returns
    /// an empty array when no services are configured. Throws `.cancelled` when the call
    /// was suppressed because another sync was already in flight (debounced). Use this
    /// from sites that need to chain work after the sync finishes (e.g. password-change
    /// re-encryption push), inspect per-service outcomes, or have caller-task cancellation
    /// propagate.
    @discardableResult
    func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult]

    /// Runs only the backend with the given id through the coordinator. Returns silently on
    /// success or no-op (no entry matches the id, or the container hasn't been installed yet).
    /// Throws `BackupSyncError` on actual sync failure or when debounced because another sync
    /// is in flight (`.cancelled`).
    ///
    /// Per-config `overwritingVault` / `allowingAnyDeviceId` come from the awaiting-flag
    /// sets — callers don't pass them. Mark via `markAllServicesAwaitingVaultOverride()` /
    /// `markAwaitingDeviceRegistration(configID:)` before triggering.
    func sync(id: UUID) async throws(BackupSyncError)

    /// Most recent successful sync timestamp for `id`, or `nil` if no successful sync recorded.
    /// Reads through to the persistent date store; intended for UI display ("Last synced …").
    func lastSyncDate(for id: UUID) -> Date?

    /// Cancels the currently running backup sync session, if any.
    func cancelCurrentSync()

    /// Live stream of session-level (`.sessionStarted` / `.sessionFinished`) and per-service
    /// (`.started` / `.finished`) events from every sync the underlying container runs. Each
    /// call returns a fresh stream — multiple subscribers can listen concurrently. Use this
    /// when a consumer wants to react to sync lifecycle as it happens (e.g. driving per-row
    /// UI) instead of polling `currentActivity` on a notification trigger.
    func syncEvents() -> AsyncStream<BackupSyncSession.Event>

    /// Convenience stream that yields once for each per-service sync that merged remote content
    /// into the local database. Filters `syncEvents()` for `.finished(_, _, .success(let outcome))`
    /// where `outcome.appliedRemoteChanges == true`. View-layer presenters use this to refresh
    /// their displayed data without seeing Backup-module event types.
    ///
    /// **Multi-emit per `syncAll`:** the convergence loop can apply remote changes from more
    /// than one service across passes, so a single `syncAll` call may yield multiple times.
    /// Each yield is a real moment of local-state mutation; subscribers whose reload work is
    /// expensive should add their own throttle.
    func syncDidApplyRemoteChanges() -> AsyncStream<Void>
}

final class BackupSyncTriggerInteractor: BackupSyncTriggerInteracting {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }

    var currentActivity: BackupSyncActivity {
        mainRepository.backupSyncContainer.currentActivity
    }

    func markAllServicesAwaitingVaultOverride() {
        mainRepository.backupSyncContainer.markAllConfigsAwaitingVaultOverride()
    }

    func markAwaitingDeviceRegistration(configID: UUID) {
        mainRepository.backupSyncContainer.markAwaitingDeviceRegistration(configID: configID)
    }

    func syncAll() {
        mainRepository.backupSyncContainer.syncAll()
    }

    @discardableResult
    func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult] {
        try await mainRepository.backupSyncContainer.syncAll()
    }

    func sync(id: UUID) async throws(BackupSyncError) {
        try await mainRepository.backupSyncContainer.sync(id)
    }

    func lastSyncDate(for id: UUID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    func cancelCurrentSync() {
        mainRepository.backupSyncContainer.cancelCurrentSync()
    }

    func syncEvents() -> AsyncStream<BackupSyncSession.Event> {
        mainRepository.backupSyncContainer.syncEvents()
    }

    func syncDidApplyRemoteChanges() -> AsyncStream<Void> {
        let upstream = mainRepository.backupSyncContainer.syncEvents()
        return AsyncStream { continuation in
            let task = Task {
                for await event in upstream {
                    if case .finished(_, _, .success(let outcome)) = event, outcome.appliedRemoteChanges {
                        continuation.yield()
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
