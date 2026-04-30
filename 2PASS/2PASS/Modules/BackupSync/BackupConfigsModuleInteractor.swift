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
    private let triggerInteractor: BackupSyncTriggerInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let notificationCenter: NotificationCenter

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        triggerInteractor: BackupSyncTriggerInteracting,
        cloudSyncInteractor: CloudSyncInteracting
    ) {
        self.configsInteractor = configsInteractor
        self.triggerInteractor = triggerInteractor
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
        triggerInteractor.currentActivity
    }

    func lastSyncDate(for id: UUID) -> Date? {
        triggerInteractor.lastSyncDate(for: id)
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
        triggerInteractor.syncAll(onEvent: onEvent)
    }

    func sync(id: UUID, onEvent: BackupSyncSession.ProgressHandler?) async {
        await triggerInteractor.sync(id: id, onEvent: onEvent)
    }

    func cancelCurrentSync() {
        triggerInteractor.cancelCurrentSync()
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
