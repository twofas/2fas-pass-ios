// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol SettingsModuleInteracting: AnyObject {
    var updatePaymentStatus: Callback? { get set }
    var isPaidUser: Bool { get }
    var appVersion: String { get }
    var syncHasError: Bool { get }
    var isSyncEnabled: Bool { get }
    var isAutoFillEnabled: Bool { get }
    var isPushNotificationsEnabled: Bool { get }
    var didAutoFillStatusChanged: NotificationCenter.Notifications { get }
    var didPushNotificationsStatusChanged: NotificationCenter.Notifications { get }
    var is2FASAuthInstalled: Bool { get }
}

final class SettingsModuleInteractor {
    var updatePaymentStatus: Callback?

    private let systemInteractor: SystemInteracting
    private let configInteractor: ConfigInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let configsInteractor: BackupSyncConfigsInteracting
    private let autoFillStatusInteractor: AutoFillStatusInteracting
    private let pushNotificationsInteractor: PushNotificationsPermissionInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting

    private let notificationCenter = NotificationCenter.default

    init(systemInteractor: SystemInteracting,
         configInteractor: ConfigInteracting,
         cloudSyncInteractor: CloudSyncInteracting,
         configsInteractor: BackupSyncConfigsInteracting,
         autoFillStatusInteractor: AutoFillStatusInteracting,
         pushNotificationsInteractor: PushNotificationsPermissionInteracting,
         paymentStatusInteractor: PaymentStatusInteracting) {
        self.systemInteractor = systemInteractor
        self.configInteractor = configInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
        self.configsInteractor = configsInteractor
        self.autoFillStatusInteractor = autoFillStatusInteractor
        self.pushNotificationsInteractor = pushNotificationsInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
        
        notificationCenter.addObserver(
                self,
                selector: #selector(updatePaymentStatusAction),
                name: .paymentStatusChanged,
                object: nil
            )
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension SettingsModuleInteractor: SettingsModuleInteracting {
    var isPaidUser: Bool {
        paymentStatusInteractor.isPremium
    }
    
    var appVersion: String {
        systemInteractor.appVersion
    }
    
    var isSyncEnabled: Bool {
        switch cloudSyncInteractor.currentState {
        case .enabled, .enabledNotAvailable:
            return true
        default:
            break
        }
        // "WebDAV is enabled" used to mean `webDAVIsConnected` (a derived flag set after a
        // successful sync). With multi-config BackupSync the equivalent is "the user has at
        // least one non-iCloud backend configured" — file-based backends (WebDAV, S3) only get
        // configs persisted when the user finishes setup.
        let hasFileBackend = configsInteractor.allConfigs.contains { config in
            switch config.kind {
            case .webDAV, .s3: return true
            case .iCloud: return false
            }
        }
        return hasFileBackend
    }
    
    var syncHasError: Bool {
        systemInteractor.syncHasError
    }
    
    var isAutoFillEnabled: Bool {
        autoFillStatusInteractor.isEnabled
    }
    
    var isPushNotificationsEnabled: Bool {
        pushNotificationsInteractor.isEnabled
    }
    
    var didAutoFillStatusChanged: NotificationCenter.Notifications {
        autoFillStatusInteractor.didStatusChanged
    }
    
    var didPushNotificationsStatusChanged: NotificationCenter.Notifications {
        pushNotificationsInteractor.didStatusChanged
    }
    
    var is2FASAuthInstalled: Bool {
        systemInteractor.is2FASAuthInstalled
    }
    
    @objc
    private func updatePaymentStatusAction() {
        updatePaymentStatus?()
    }
}
