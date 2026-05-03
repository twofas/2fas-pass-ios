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
    var cloudState: CloudState { get }
    var currentActivity: BackupSyncActivity { get }
    var cloudStateChanged: Callback? { get set }

    func lastSyncDate(for id: UUID) -> Date?
    @discardableResult func addiCloud() -> UUID?
    func remove(id: UUID, kind: SyncServiceKind)
    /// Fire-and-forget at background `.utility` priority — for non-user-driven sync
    /// (post-mutation propagation, refresh on appearance). Internally detached.
    func syncAll()
    /// Awaitable — for user-initiated "Sync Now" taps where the calling `Task` inherits the
    /// user-facing priority (`.userInitiated` from the MainActor button handler). The work
    /// still runs off MainActor because the underlying container method is non-isolated.
    func syncAll() async
    func sync(id: UUID) async
    func cancelCurrentSync()
    func progressEvents() -> AsyncStream<BackupSyncSession.ProgressEvent>
}

@MainActor
final class BackupConfigsModuleInteractor: BackupConfigsModuleInteracting {

    var cloudStateChanged: Callback?

    private let configsInteractor: BackupSyncConfigsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let notificationCenter: NotificationCenter

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        cloudSyncInteractor: CloudSyncInteracting
    ) {
        self.configsInteractor = configsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
        self.notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(handleCloudStateChanged),
            name: .cloudStateChanged,
            object: nil
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    var allConfigs: [BackupConfig] {
        configsInteractor.allConfigs
    }

    var cloudState: CloudState {
        cloudSyncInteractor.currentState
    }

    var currentActivity: BackupSyncActivity {
        syncTriggerInteractor.currentActivity
    }

    func lastSyncDate(for id: UUID) -> Date? {
        syncTriggerInteractor.lastSyncDate(for: id)
    }

    @discardableResult
    func addiCloud() -> UUID? {
        let id = configsInteractor.addiCloudConfig()
        if id != nil, case .disabled = cloudSyncInteractor.currentState {
            cloudSyncInteractor.enable()
        }
        return id
    }

    func remove(id: UUID, kind: SyncServiceKind) {
        configsInteractor.removeConfig(id: id)
        if kind == .iCloud {
            cloudSyncInteractor.disable()
        }
    }

    func syncAll() {
        syncTriggerInteractor.syncAll()
    }

    func syncAll() async {
        await syncTriggerInteractor.syncAll()
    }

    func sync(id: UUID) async {
        await syncTriggerInteractor.sync(id: id)
    }

    func cancelCurrentSync() {
        syncTriggerInteractor.cancelCurrentSync()
    }

    func progressEvents() -> AsyncStream<BackupSyncSession.ProgressEvent> {
        syncTriggerInteractor.progressEvents()
    }

    @objc
    private func handleCloudStateChanged() {
        cloudStateChanged?()
    }
}
