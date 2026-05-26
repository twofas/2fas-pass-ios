// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Backup

public protocol BackupSyncTriggerInteracting: AnyObject {
    var currentActivity: BackupSyncActivity { get }

    func markAllServicesAwaitingVaultOverride()

    func markAwaitingDeviceRegistration(configID: BackupConfig.ID)

    func syncAll()

    @discardableResult
    func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult]

    func sync(id: BackupConfig.ID)

    func sync(id: BackupConfig.ID) async throws(BackupSyncError)

    func lastSyncDate(for id: BackupConfig.ID) -> Date?

    func lastSyncError(for id: BackupConfig.ID) -> BackupSyncError?

    var hasAnySyncError: Bool { get }

    func cancelCurrentSync()

    func handlePushNotification()

    func cancelSync(id: BackupConfig.ID)

    func syncEvents() -> AsyncStream<BackupSyncSession.Event>

    func syncDidApplyRemoteChanges() -> AsyncStream<Void>

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
