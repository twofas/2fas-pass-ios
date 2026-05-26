// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Backup

/// Trigger calls no-op until `BackupSyncInstalling.initialize()` has wired the container.
public protocol BackupSyncTriggerInteracting: AnyObject {
    var currentActivity: BackupSyncActivity { get }

    func markAllServicesAwaitingVaultOverride()

    /// Persists across retries; cleared by the first successful sync that honors it.
    func markAwaitingDeviceRegistration(configID: BackupConfig.ID)

    func syncAll()

    /// Throws `.cancelled` when another sync is already in flight (debounce, not queue).
    @discardableResult
    func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult]

    func sync(id: BackupConfig.ID)

    /// Silent no-op when no config matches `id`. `.cancelled` on debounce.
    func sync(id: BackupConfig.ID) async throws(BackupSyncError)

    func lastSyncDate(for id: BackupConfig.ID) -> Date?

    /// Process-scoped — not persisted; cleared on next success.
    func lastSyncError(for id: BackupConfig.ID) -> BackupSyncError?

    var hasAnySyncError: Bool { get }

    func cancelCurrentSync()

    /// Bypasses the container's debounce so `CloudSync`'s `fromPush: true` semantics
    /// (mark `needsResync` on a sync past its fetch phase) are preserved.
    func handlePushNotification()

    /// No-op when `id` isn't currently active.
    func cancelSync(id: BackupConfig.ID)

    func syncEvents() -> AsyncStream<BackupSyncSession.Event>

    /// The convergence loop can yield this multiple times per `syncAll` — subscribers with
    /// expensive reload work should throttle.
    func syncDidApplyRemoteChanges() -> AsyncStream<Void>

    /// Yields only on real transitions; seeded with the value at subscription time so a
    /// same-value upstream signal is suppressed.
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
