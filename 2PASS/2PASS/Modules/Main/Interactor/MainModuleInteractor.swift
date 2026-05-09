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

    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let configsInteractor: BackupSyncConfigsInteracting
    private let systemInteractor: SystemInteracting
    private let quickSetupInteractor: QuickSetupInteracting
    private let loginInteractor: LoginInteracting
    private let notificationCenter: NotificationCenter

    private var syncErroredLately = false
    /// Tracks the long-lived `syncEvents()` consumer that drives badge updates on session
    /// start/finish. `var ...?` per the Swift two-phase init exception (CLAUDE.md): the Task
    /// captures `[weak self]` and so cannot be assigned during phase-one init.
    private var activitySubscription: Task<Void, Never>?
    /// Tracks the long-lived `BackupConfigsDidChange` consumer that drives a badge refresh on
    /// config CRUD. `BackupSyncContainer.saveConfigs(_:)` clears `lastErrors[id]` for any
    /// removed config, so `hasAnySyncError` can flip to `false` without a sync session firing
    /// — without this subscription the badge would stay stuck on the prior error state until
    /// the next `.sessionStarted`/`.sessionFinished` event. Same `var ...?` two-phase-init
    /// reasoning as `activitySubscription`.
    private var configsChangeSubscription: Task<Void, Never>?

    init(
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        configsInteractor: BackupSyncConfigsInteracting,
        systemInteractor: SystemInteracting,
        quickSetupInteractor: QuickSetupInteracting,
        loginInteractor: LoginInteracting
    ) {
        self.syncTriggerInteractor = syncTriggerInteractor
        self.configsInteractor = configsInteractor
        self.systemInteractor = systemInteractor
        self.quickSetupInteractor = quickSetupInteractor
        self.loginInteractor = loginInteractor
        self.notificationCenter = NotificationCenter.default

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

        configsChangeSubscription = Task { [weak self] in
            guard let messages = self?.configsInteractor.configsDidChange else { return }
            for await _ in messages {
                self?.updateBadgeAction()
            }
        }
    }

    deinit {
        activitySubscription?.cancel()
        configsChangeSubscription?.cancel()
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
        // While any sync is in flight, hold the previous flag — avoids flickering between
        // "running, no error yet" and "running, prior error" mid-session. The session emits
        // `.sessionFinished` after every per-service `.finished` has written its outcome, so
        // this method picks up the post-run state on that final event. After the refactor,
        // `currentActivity.isRunning` already covers iCloud (CloudSyncAdapter sync runs go
        // through the same session) and `hasAnySyncError` already collects iCloud-side
        // failures alongside WebDAV/S3, so the previous OR with `cloudSyncInteractor.currentState`
        // collapses to the unified backup-sync surface.
        if syncTriggerInteractor.currentActivity.isRunning {
            postBadgeChange(syncErroredLately)
            return
        }

        let showErrorBadge = syncTriggerInteractor.hasAnySyncError
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
