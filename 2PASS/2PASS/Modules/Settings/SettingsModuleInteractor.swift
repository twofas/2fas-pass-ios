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
    var syncErrorChanges: AsyncStream<Bool> { get }
    var syncEnabledChanges: AsyncStream<Bool> { get }
    var is2FASAuthInstalled: Bool { get }
}

final class SettingsModuleInteractor {
    var updatePaymentStatus: Callback?

    private let systemInteractor: SystemInteracting
    private let configInteractor: ConfigInteracting
    private let configsInteractor: BackupSyncConfigsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let autoFillStatusInteractor: AutoFillStatusInteracting
    private let pushNotificationsInteractor: PushNotificationsPermissionInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting

    private let notificationCenter = NotificationCenter.default

    init(systemInteractor: SystemInteracting,
         configInteractor: ConfigInteracting,
         configsInteractor: BackupSyncConfigsInteracting,
         syncTriggerInteractor: BackupSyncTriggerInteracting,
         autoFillStatusInteractor: AutoFillStatusInteracting,
         pushNotificationsInteractor: PushNotificationsPermissionInteracting,
         paymentStatusInteractor: PaymentStatusInteracting) {
        self.systemInteractor = systemInteractor
        self.configInteractor = configInteractor
        self.configsInteractor = configsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
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
        !configsInteractor.allConfigs.isEmpty
    }

    var syncHasError: Bool {
        syncTriggerInteractor.hasAnySyncError
    }

    var syncErrorChanges: AsyncStream<Bool> {
        syncTriggerInteractor.syncErrorChanges
    }

    var syncEnabledChanges: AsyncStream<Bool> {
        let configsInteractor = self.configsInteractor
        return AsyncStream { continuation in
            let task = Task {
                var lastYielded = !configsInteractor.allConfigs.isEmpty
                for await _ in configsInteractor.configsDidChange {
                    let current = !configsInteractor.allConfigs.isEmpty
                    guard current != lastYielded else { continue }
                    lastYielded = current
                    continuation.yield(current)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
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
