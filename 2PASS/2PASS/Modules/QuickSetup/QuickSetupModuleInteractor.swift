// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common
import Backup

protocol QuickSetupModuleInteracting: AnyObject {
    
    func finishQuickSetup()
    
    // MARK: AutoFill
    
    var isAutoFillEnabled: Bool { get }
    
    func turnOnAutoFill()
    func turnOffAutoFill()
    
    var didAutoFillStatusChanged: NotificationCenter.Notifications { get }
    
    // MARK: iCloud
    
    var isCloudEnabled: Bool { get }

    func turnOnCloud()
    func turnOffCloud()

    var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> { get }

    var syncPremiumNeededScreen: NotificationCenter.Notifications { get }
    
    // MARK: Security Tier
    
    var defaultSecurityTier: ItemProtectionLevel { get }
}

final class QuickSetupModuleInteractor: QuickSetupModuleInteracting {

    private let autoFillStatusInteractor: AutoFillStatusInteracting
    private let configsInteractor: BackupSyncConfigsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let configInteractor: ConfigInteracting
    private let quickSetupInteractor: QuickSetupInteracting

    init(
        autoFillStatusInteractor: AutoFillStatusInteracting,
        configsInteractor: BackupSyncConfigsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        configInteractor: ConfigInteracting,
        quickSetupInteractor: QuickSetupInteracting
    ) {
        self.autoFillStatusInteractor = autoFillStatusInteractor
        self.configsInteractor = configsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.configInteractor = configInteractor
        self.quickSetupInteractor = quickSetupInteractor
    }

    var isAutoFillEnabled: Bool {
        autoFillStatusInteractor.isEnabled
    }

    var didAutoFillStatusChanged: NotificationCenter.Notifications {
        autoFillStatusInteractor.didStatusChanged
    }

    func turnOnAutoFill() {
        autoFillStatusInteractor.turnOn()
    }

    func turnOffAutoFill() {
        autoFillStatusInteractor.turnOff()
    }

    var isCloudEnabled: Bool {
        configsInteractor.allConfigs.hasICloud
    }

    func turnOnCloud() {
        // Persisting the iCloud config is the enable signal — the container's
        // `saveConfigs(_:)` diff detects the iCloud-added transition and runs
        // `cloudSync.enable()` internally. After enable, kick off an initial sync so any
        // existing local vault state is pushed up to iCloud immediately rather than waiting
        // for the next post-mutation `syncAll`.
        guard !configsInteractor.allConfigs.hasICloud else { return }
        guard let id = configsInteractor.addiCloudConfig() else { return }
        Task { try? await syncTriggerInteractor.sync(id: id) }
    }

    func turnOffCloud() {
        // Mirror of `turnOnCloud()`: removing the iCloud entry triggers the disable side
        // effect inside the container.
        if let id = configsInteractor.allConfigs.iCloudEntry?.id {
            syncTriggerInteractor.cancelSync(id: id)
            configsInteractor.removeConfig(id: id)
        }
    }

    var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> {
        configsInteractor.configsDidChange
    }

    var syncPremiumNeededScreen: NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: .presentSyncPremiumNeededScreen)
    }
    
    var defaultSecurityTier: ItemProtectionLevel {
        configInteractor.currentDefaultProtectionLevel
    }
    
    func finishQuickSetup() {
        quickSetupInteractor.finishQuickSetup()
    }
}
