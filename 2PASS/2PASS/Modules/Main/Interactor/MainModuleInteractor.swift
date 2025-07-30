// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol MainModuleInteracting: AnyObject {
    var updateBadge: ((Bool) -> Void)? { get set }
    var paymentScreen: Callback? { get set }
    var shouldShowQuickSetup: Bool { get }
    func viewIsVisible()
}

final class MainModuleInteractor {
    var updateBadge: ((Bool) -> Void)?
    var paymentScreen: Callback?
    
    private let webDAVBackupInteractor: WebDAVBackupInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    private let webDAVStateInteractor: WebDAVStateInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let systemInteractor: SystemInteracting
    private let quickSetupInteractor: QuickSetupInteracting
    private let notificationCenter: NotificationCenter
    
    private var syncErroredLately = false
    
    private var awaitsWebDAVSyncEnd = false
    
    init(
        webDAVBackupInteractor: WebDAVBackupInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting,
        webDAVStateInteractor: WebDAVStateInteracting,
        cloudSyncInteractor: CloudSyncInteracting,
        systemInteractor: SystemInteracting,
        quickSetupInteractor: QuickSetupInteracting
    ) {
        self.webDAVBackupInteractor = webDAVBackupInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
        self.webDAVStateInteractor = webDAVStateInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
        self.systemInteractor = systemInteractor
        self.quickSetupInteractor = quickSetupInteractor
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
        notificationCenter.addObserver(
            self,
            selector: #selector(updateWebDAVStateChange),
            name: .webDAVStateChange,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(passwordWasChanged),
            name: .passwordWasChanged,
            object: nil
        )
        
        syncChangeTriggerInteractor.newChangeForSync = { [weak self] in
            Log("MainModuleInteractor - trigger on change", module: .moduleInteractor)
            self?.sync()
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension MainModuleInteractor: MainModuleInteracting {
    
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
        let cloudHasSynced = cloudSyncInteractor.currentState.isSynced
        let webdavHasSynced = webDAVStateInteractor.state.isSynced
        
        if cloudHasSynced || webdavHasSynced {
            syncErroredLately = false
            postBadgeChange(false)
            return
        }
        
        let cloudIsSyncing = cloudSyncInteractor.currentState.isSyncing
        let webdavIsSyncing = webDAVStateInteractor.state.isSyncing
        
        if cloudIsSyncing || webdavIsSyncing {
            postBadgeChange(syncErroredLately)
            return
        }

        let cloudHasError = cloudSyncInteractor.currentState.hasError && cloudSyncInteractor.lastSuccessSyncDate != nil
        let webdavHasError = webDAVStateInteractor.state.hasError && webDAVStateInteractor.isConnected
        
        let showErrorBadge = cloudHasError || webdavHasError
        syncErroredLately = showErrorBadge
        
        postBadgeChange(showErrorBadge)
    }
    
    @objc
    func presentPaymentScreen() {
        paymentScreen?()
    }
    
    @objc
    func updateWebDAVStateChange() {
        updateBadgeAction()
        
        if webDAVStateInteractor.isConnected && webDAVStateInteractor.awaitsVaultOverrideAfterPasswordChange {
            if webDAVStateInteractor.state == .synced {
                if awaitsWebDAVSyncEnd {
                    awaitsWebDAVSyncEnd = false
                    sync()
                } else {
                    webDAVStateInteractor.clearAwaitsVaultOverrideAfterPasswordChange()
                }
            } else if webDAVStateInteractor.state == .error(.passwordChanged) && awaitsWebDAVSyncEnd {
                awaitsWebDAVSyncEnd = false
                sync()
            }
        }
    }
    
    @objc
    func passwordWasChanged() {
        if webDAVStateInteractor.isConnected {
            webDAVStateInteractor.setAwaitsVaultOverrideAfterPasswordChange()
            if webDAVStateInteractor.state == .synced {
                sync()
            } else {
                awaitsWebDAVSyncEnd = true
            }
        }
    }
    
    func sync() {
        if webDAVStateInteractor.isConnected {
            Log("MainModuleInteractor - triggering sync on Main", module: .moduleInteractor)
            webDAVBackupInteractor.sync()
        }
        cloudSyncInteractor.synchronize()
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
