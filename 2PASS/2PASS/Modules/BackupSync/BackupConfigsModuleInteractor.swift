// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data
import Common

@MainActor
protocol BackupConfigsModuleInteracting: AnyObject {
    var allConfigs: [BackupConfig] { get }
    var currentActivity: BackupSyncActivity { get }
    var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> { get }

    func lastSyncDate(for id: UUID) -> Date?
    func lastSyncError(for id: UUID) -> BackupSyncError?
    @discardableResult func addiCloud() -> UUID?
    func remove(id: UUID)
    func syncAll() async
    func sync(id: UUID) async
    func cancelCurrentSync()
    func syncEvents() -> AsyncStream<BackupSyncSession.Event>
    func displayDomain(from host: String) -> String
}

@MainActor
final class BackupConfigsModuleInteractor: BackupConfigsModuleInteracting {

    private let configsInteractor: BackupSyncConfigsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let uriInteractor: URIInteracting

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        uriInteractor: URIInteracting
    ) {
        self.configsInteractor = configsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.uriInteractor = uriInteractor
    }

    var allConfigs: [BackupConfig] {
        configsInteractor.allConfigs
    }

    var currentActivity: BackupSyncActivity {
        syncTriggerInteractor.currentActivity
    }

    var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> {
        configsInteractor.configsDidChange
    }

    func lastSyncDate(for id: UUID) -> Date? {
        syncTriggerInteractor.lastSyncDate(for: id)
    }

    func lastSyncError(for id: UUID) -> BackupSyncError? {
        syncTriggerInteractor.lastSyncError(for: id)
    }

    @discardableResult
    func addiCloud() -> UUID? {
        // Persisting the iCloud config is the enable signal — the container's
        // `saveConfigs(_:)` diff calls `cloudSync.enable()` internally. After enable, kick
        // an initial sync so any existing local vault state is pushed up to iCloud
        // immediately rather than waiting for the next post-mutation `syncAll`. Mirrors
        // `QuickSetupModuleInteractor.turnOnCloud()`.
        guard let id = configsInteractor.addiCloudConfig() else { return nil }
        Task { try? await syncTriggerInteractor.sync(id: id) }
        return id
    }

    func remove(id: UUID) {
        // Mirror of `addiCloud()`: removing an iCloud entry triggers the container's
        // disable side effect. The container's `saveConfigs(_:)` diff resolves the iCloud
        // teardown path, so this is uniform across kinds.
        configsInteractor.removeConfig(id: id)
    }

    func syncAll() {
        syncTriggerInteractor.syncAll()
    }

    func syncAll() async {
        try? await syncTriggerInteractor.syncAll()
    }

    func sync(id: UUID) async {
        try? await syncTriggerInteractor.sync(id: id)
    }

    func cancelCurrentSync() {
        syncTriggerInteractor.cancelCurrentSync()
    }

    func syncEvents() -> AsyncStream<BackupSyncSession.Event> {
        syncTriggerInteractor.syncEvents()
    }

    func displayDomain(from host: String) -> String {
        uriInteractor.displayDomain(from: host)
    }
}
