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
    var backupSyncActivityChanged: Callback? { get set }

    func lastSyncDate(for id: UUID) -> Date?
    @discardableResult func addiCloud() -> UUID?
    func remove(id: UUID, kind: SyncServiceKind)
    func syncAll(onEvent: BackupSyncSession.ProgressHandler?)
    func sync(id: UUID, onEvent: BackupSyncSession.ProgressHandler?) async
    func cancelCurrentSync()
}

@MainActor
final class BackupConfigsModuleInteractor: BackupConfigsModuleInteracting {

    var cloudStateChanged: Callback?
    var backupSyncActivityChanged: Callback?

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
        notificationCenter.addObserver(
            self,
            selector: #selector(handleBackupSyncActivityChanged),
            name: .backupSyncActivityChanged,
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

    func syncAll(onEvent: BackupSyncSession.ProgressHandler?) {
        syncTriggerInteractor.syncAll(onEvent: onEvent)
    }

    func sync(id: UUID, onEvent: BackupSyncSession.ProgressHandler?) async {
        await syncTriggerInteractor.sync(id: id, onEvent: onEvent)
    }

    func cancelCurrentSync() {
        syncTriggerInteractor.cancelCurrentSync()
    }

    @objc
    private func handleCloudStateChanged() {
        cloudStateChanged?()
    }

    @objc
    private func handleBackupSyncActivityChanged() {
        backupSyncActivityChanged?()
    }
}
