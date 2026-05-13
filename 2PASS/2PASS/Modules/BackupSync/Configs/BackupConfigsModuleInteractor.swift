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

    func remove(id: UUID) {
        // Removing an iCloud entry triggers the container's disable side effect. The
        // container's `saveConfigs(_:)` diff resolves the iCloud teardown path, so this
        // is uniform across kinds.
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
