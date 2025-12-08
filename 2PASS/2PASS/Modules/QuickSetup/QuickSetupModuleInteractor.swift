// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common

protocol QuickSetupModuleInteracting: AnyObject {
    
    func finishQuickSetup()
    
    // MARK: AutoFill
    
    var isAutoFillEnabled: Bool { get }
    
    func turnOnAutoFill()
    func turnOffAutoFill()
    
    var didAutoFillStatusChanged: NotificationCenter.Notifications { get }
    
    // MARK: iCloud
    
    var isCloudEnabled: Bool { get }
    var cloudState: CloudState { get }

    func turnOnCloud()
    func turnOffCloud()
    
    var didCloudStatusChanged: NotificationCenter.Notifications { get }
    var syncPremiumNeededScreen: NotificationCenter.Notifications { get }
    
    // MARK: Security Tier
    
    var defaultSecurityTier: ItemProtectionLevel { get }
}

final class QuickSetupModuleInteractor: QuickSetupModuleInteracting {
    
    private let autoFillStatusInteractor: AutoFillStatusInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let configInteractor: ConfigInteracting
    private let quickSetupInteractor: QuickSetupInteracting

    init(autoFillStatusInteractor: AutoFillStatusInteracting, cloudSyncInteractor: CloudSyncInteracting, configInteractor: ConfigInteracting, quickSetupInteractor: QuickSetupInteracting) {
        self.autoFillStatusInteractor = autoFillStatusInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
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
        if case .enabled = cloudState {
            return true
        } else if case .enabledNotAvailable = cloudState {
            return true
        } else {
            return false
        }
    }
    
    var cloudState: CloudState {
        cloudSyncInteractor.currentState
    }
    
    func turnOnCloud() {
        switch cloudSyncInteractor.currentState {
        case .disabled: cloudSyncInteractor.enable()
        default: break
        }
    }
    
    func turnOffCloud() {
        switch cloudSyncInteractor.currentState {
        case .enabled, .enabledNotAvailable: cloudSyncInteractor.disable()
        default: break
        }
    }
    
    var didCloudStatusChanged: NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: .cloudStateChanged, object: nil)
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
