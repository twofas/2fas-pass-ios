// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data
import Common

protocol MainModuleInteracting: AnyObject {
    var updateBadge: ((Bool) -> Void)? { get set }
    var paymentScreen: Callback? { get set }
    var shouldShowQuickSetup: Bool { get }
    var shouldRequestForBiometryToLogin: Bool { get }

    func viewIsVisible()
}

final class MainModuleInteractor {
    var updateBadge: ((Bool) -> Void)?
    var paymentScreen: Callback?

    private let cloudSyncInteractor: CloudSyncInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let systemInteractor: SystemInteracting
    private let quickSetupInteractor: QuickSetupInteracting
    private let loginInteractor: LoginInteracting
    private let notificationCenter: NotificationCenter

    private var syncErroredLately = false
    /// Tracks the long-lived `syncEvents()` consumer that drives badge updates on session
    /// start/finish. `var ...?` per the Swift two-phase init exception (CLAUDE.md): the Task
    /// captures `[weak self]` and so cannot be assigned during phase-one init.
    private var activitySubscription: Task<Void, Never>?

    init(
        cloudSyncInteractor: CloudSyncInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        systemInteractor: SystemInteracting,
        quickSetupInteractor: QuickSetupInteracting,
        loginInteractor: LoginInteracting
    ) {
        self.cloudSyncInteractor = cloudSyncInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.systemInteractor = systemInteractor
        self.quickSetupInteractor = quickSetupInteractor
        self.loginInteractor = loginInteractor
        self.notificationCenter = NotificationCenter.default

        cloudSyncInteractor.setup(takeoverVault: false)

        notificationCenter.addObserver(
            self,
            selector: #selector(userLoggedIn),
            name: .userLoggedIn,
            object: nil
        )
        notificationCenter.addObserver(
                self,
                selector: #selector(presentPaymentScreen),
                name: .presentPaymentScreen,
                object: nil
            )
        notificationCenter.addObserver(
            self,
            selector: #selector(updateBadgeAction),
            name: .cloudStateChanged,
            object: nil
        )

        activitySubscription = Task { [weak self] in
            guard let stream = self?.syncTriggerInteractor.syncEvents() else { return }
            for await event in stream {
                switch event {
                case .sessionStarted, .sessionFinished:
                    self?.updateBadgeAction()
                case .started, .finished:
                    break
                }
            }
        }
    }

    deinit {
        activitySubscription?.cancel()
        notificationCenter.removeObserver(self)
    }
}

extension MainModuleInteractor: MainModuleInteracting {
    var shouldRequestForBiometryToLogin: Bool {
        loginInteractor.shouldRequestForBiometryToLogin
    }
    
    var shouldShowQuickSetup: Bool {
        quickSetupInteractor.shouldShowQuickSetup
    }
    
    func viewIsVisible() {
        Log("MainModuleInteractor - Main is visible", module: .moduleInteractor)
        sync()
    }
}

private extension MainModuleInteractor {
    @objc
    func userLoggedIn() {
        Log("MainModuleInteractor - user logged in", module: .moduleInteractor)
        sync()
    }
    
    @objc
    func updateBadgeAction() {
        // Backup-sync error state is no longer persisted — the new `BackupSyncContainer` reports
        // errors per-run via the session's `EventHandler`, not as a recoverable property. The
        // badge now reflects only iCloud's terminal state (still persisted via
        // `CloudSyncInteractor`) plus a "currently syncing" indicator that includes every backend
        // wired into the container.
        let cloudHasSynced = cloudSyncInteractor.currentState.isSynced
        if cloudHasSynced {
            syncErroredLately = false
            postBadgeChange(false)
            return
        }

        let backupIsRunning = syncTriggerInteractor.currentActivity.isRunning
        let cloudIsSyncing = cloudSyncInteractor.currentState.isSyncing
        if backupIsRunning || cloudIsSyncing {
            postBadgeChange(syncErroredLately)
            return
        }

        let showErrorBadge = cloudSyncInteractor.currentState.hasError
        syncErroredLately = showErrorBadge
        postBadgeChange(showErrorBadge)
    }

    @objc
    func presentPaymentScreen() {
        paymentScreen?()
    }

    func sync() {
        Log("MainModuleInteractor - triggering sync on Main", module: .moduleInteractor)
        // Drives the new `BackupSyncContainer` over every config registered through the
        // BackupConfigs UI (WebDAV, S3, iCloud). Fire-and-forget — the previous legacy calls
        // (`webDAVBackupInteractor.sync()`, `cloudSyncInteractor.synchronize()`) had the same
        // semantics. The container no-ops when no configs are registered.
        syncTriggerInteractor.syncAll()
    }
    
    func postBadgeChange(_ showErrorBadge: Bool) {
        DispatchQueue.main.async {
            self.updateBadge?(showErrorBadge)
            self.systemInteractor.setSyncHasError(showErrorBadge)
        }
        NotificationCenter.default
            .post(name: .settingsSyncStateChanged, object: nil)
    }
}
