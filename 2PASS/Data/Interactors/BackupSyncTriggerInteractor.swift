// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Backup

/// Sync trigger entry points plus read access to per-config last-sync timestamps and errors.
/// Routes through the `BackupSyncContainer` installed on `MainRepository`. Trigger calls
/// no-op until `backupSyncSetupInteractor().initialize()` has installed the container.
public protocol BackupSyncTriggerInteracting: AnyObject {
    var currentActivity: BackupSyncActivity { get }

    /// Marks every registered config for vault overwrite on its next sync.
    /// Used by the password-change flow.
    func markAllServicesAwaitingVaultOverride()

    /// Marks `configID` for `allowingAnyDeviceId: true` on its next sync. Persists across
    /// retries; cleared by the first successful sync.
    func markAwaitingDeviceRegistration(configID: BackupConfig.ID)

    /// Fire-and-forget: detached `.utility`-priority task. Cancel via `cancelCurrentSync()`.
    func syncAll()

    /// Awaitable. Throws `.cancelled` when debounced (another sync already in flight).
    @discardableResult
    func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult]

    /// Fire-and-forget single-config trigger. Cancel via `cancelSync(id:)` /
    /// `cancelCurrentSync()`.
    func sync(id: BackupConfig.ID)

    /// Awaitable. Silent no-op when no config matches `id` or the container isn't installed.
    /// Throws on actual failure or `.cancelled` when debounced.
    func sync(id: BackupConfig.ID) async throws(BackupSyncError)

    /// Most recent successful sync timestamp for `id`; persistent across launches.
    func lastSyncDate(for id: BackupConfig.ID) -> Date?

    /// Most recent failure for `id` in this app process; cleared on next success.
    /// Process-scoped — does not survive an app restart.
    func lastSyncError(for id: BackupConfig.ID) -> BackupSyncError?

    /// `true` when any registered config has a recorded last-sync error in this process.
    /// Drives the global "backups need attention" badge.
    var hasAnySyncError: Bool { get }

    func cancelCurrentSync()

    /// Forwards a CloudKit silent push. Bypasses the container's debounce so the
    /// `fromPush: true` semantics inside `CloudSync` (mark `needsResync` on an in-flight
    /// sync past its fetch phase) are preserved.
    func handlePushNotification()

    /// Per-id cancel; no-op when `id` isn't currently active.
    func cancelSync(id: BackupConfig.ID)

    /// Multi-subscriber session/service event stream.
    func syncEvents() -> AsyncStream<BackupSyncSession.Event>

    /// Filters `syncEvents()` for successful per-service syncs that merged remote content
    /// into the local database. The convergence loop can yield this multiple times per
    /// `syncAll` call — subscribers with expensive reload work should throttle themselves.
    func syncDidApplyRemoteChanges() -> AsyncStream<Void>

    /// Yields the current `hasAnySyncError` value only on real transitions. Seeded with
    /// the value at subscription time so a same-value upstream signal is suppressed.
    var syncErrorChanges: AsyncStream<Bool> { get }
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

    func markAwaitingDeviceRegistration(configID: BackupConfig.ID) {
        mainRepository.backupSyncContainer.markAwaitingDeviceRegistration(configID: configID)
    }

    func syncAll() {
        mainRepository.backupSyncContainer.syncAll()
    }

    @discardableResult
    func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult] {
        try await mainRepository.backupSyncContainer.syncAll()
    }

    func sync(id: BackupConfig.ID) {
        mainRepository.backupSyncContainer.sync(id)
    }

    func sync(id: BackupConfig.ID) async throws(BackupSyncError) {
        try await mainRepository.backupSyncContainer.sync(id)
    }

    func lastSyncDate(for id: BackupConfig.ID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    func lastSyncError(for id: BackupConfig.ID) -> BackupSyncError? {
        // No persistence layer behind this — reads the container's in-memory store
        // directly, unlike `lastSyncDate(for:)`.
        mainRepository.backupSyncContainer.lastSyncError(for: id)
    }

    var hasAnySyncError: Bool {
        mainRepository.backupSyncContainer.hasAnySyncError
    }

    func cancelCurrentSync() {
        mainRepository.backupSyncContainer.cancelCurrentSync()
    }

    func cancelSync(id: BackupConfig.ID) {
        mainRepository.backupSyncContainer.cancelSync(id: id)
    }

    func handlePushNotification() {
        mainRepository.backupSyncContainer.handlePush()
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

    var syncErrorChanges: AsyncStream<Bool> {
        let container = mainRepository.backupSyncContainer
        let events = container.syncEvents()
        let configChanges = container.configsDidChange
        return AsyncStream { continuation in
            // Lock serializes the read-compare-update against the two upstream tasks,
            // which fire independently and could otherwise race a duplicate yield.
            let lastYielded = OSAllocatedUnfairLock<Bool>(initialState: container.hasAnySyncError)
            let yieldIfChanged: @Sendable () -> Void = {
                let valueToYield: Bool? = lastYielded.withLock { last in
                    let current = container.hasAnySyncError
                    guard last != current else { return nil }
                    last = current
                    return current
                }
                if let valueToYield {
                    continuation.yield(valueToYield)
                }
            }
            let eventsTask = Task {
                for await event in events {
                    if case .sessionFinished = event {
                        yieldIfChanged()
                    }
                }
            }
            let configsTask = Task {
                for await _ in configChanges {
                    yieldIfChanged()
                }
            }
            continuation.onTermination = { _ in
                eventsTask.cancel()
                configsTask.cancel()
            }
        }
    }
}
