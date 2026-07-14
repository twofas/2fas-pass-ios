// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CommonUI
import Data
import Common

enum SettingsDestination: RouterDestination {
    case security
    case customization
    case autoFill
    case deletedData
    case knownWebBrowsers
    case pushNotifications
    case sync
    case importExport
    case transferItems
    case manageSubscription
    case about
    case helpCenter
    case discord
    case manageVaults
    case authenticate(config: LoginModuleInteractorConfig, onSuccess: Callback)

    var id: String {
        switch self {
        case .security: "security"
        case .customization: "customization"
        case .autoFill: "autoFill"
        case .deletedData: "deletedData"
        case .knownWebBrowsers: "knownWebBrowsers"
        case .pushNotifications: "pushNotifications"
        case .sync: "sync"
        case .importExport: "importExport"
        case .transferItems: "transferItems"
        case .manageSubscription: "manageSubscription"
        case .about: "about"
        case .helpCenter: "helpCenter"
        case .discord: "discord"
        case .manageVaults: "manageVaults"
        case .authenticate: "authenticate"
        case .debug: "debug"
        }
    }
    case debug
}

@Observable
final class SettingsPresenter {
    
    var destination: SettingsDestination?
    private let interactor: SettingsModuleInteracting
    
    private(set) var autoFillStatus: String = ""
    private(set) var subscriptionStatus: String = String(localized: .subscriptionFreePlan)
    private(set) var pushNotificationsStatus: PushNotificationsStatus = .unknown
    private(set) var syncStatus: String = ""
    private(set) var hasSyncError: Bool = false
    private(set) var isPaidUser = false
    
    var is2FASAuthInstalled: Bool {
        interactor.is2FASAuthInstalled
    }
    
    var version: String {
        interactor.appVersion
    }
    
    init(interactor: SettingsModuleInteracting) {
        self.interactor = interactor
        refreshAutoFillStatus()
        refreshPushNotificationsStatus()
        
        interactor.updatePaymentStatus = { [weak self] in
            self?.refreshSubscriptionStatus()
        }
    }
}

extension SettingsPresenter {
    
    func onAppear() {
        refreshAutoFillStatus()
        refreshPushNotificationsStatus()
        refreshSyncStatus(hasError: interactor.syncHasError, isEnabled: interactor.isSyncEnabled)
        refreshSubscriptionStatus()
    }
    
    func observeAutoFillStatusChanged() async {
        for await _ in interactor.didAutoFillStatusChanged {
            refreshAutoFillStatus()
        }
    }
    
    func observePushNotificationsStatusChanged() async {
        for await _ in interactor.didPushNotificationsStatusChanged {
            refreshPushNotificationsStatus()
        }
    }
    
    func observeSyncErrorChanges() async {
        for await hasError in interactor.syncErrorChanges {
            await MainActor.run {
                refreshSyncStatus(hasError: hasError, isEnabled: interactor.isSyncEnabled)
            }
        }
    }

    func observeSyncEnabledChanges() async {
        for await isEnabled in interactor.syncEnabledChanges {
            await MainActor.run {
                refreshSyncStatus(hasError: interactor.syncHasError, isEnabled: isEnabled)
            }
        }
    }
    
    func onSecurity() {
        destination = .security
    }
    
    func onCustomization() {
        destination = .customization
    }
    
    func onAutoFill() {
        destination = .autoFill
    }
    
    func onDeletedData() {
        destination = .deletedData
    }

    func onManageVaults() {
        Task { @MainActor in
            if await interactor.verifyUsingBiometryIfAvailable() {
                interactor.recreateSeedSaltWordsMasterKey()
                destination = .manageVaults
            } else {
                destination = .authenticate(
                    config: .init(allowBiometrics: true, loginType: .verify(savePassword: true)),
                    onSuccess: { [weak self] in
                        self?.interactor.recreateSeedSaltWordsMasterKey()
                        self?.destination = nil
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(600))
                            self?.destination = .manageVaults
                        }
                    }
                )
            }
        }
    }
    
    func onSubscription() {
        if interactor.isPaidUser {
            destination = .manageSubscription
        } else {
            NotificationCenter.default.post(name: .presentPaymentScreen, object: nil)
        }
    }
    
    func onKnownWebBrowsers() {
        destination = .knownWebBrowsers
    }
    
    func onPushNotifications() {
        destination = .pushNotifications
    }
    
    func onSync() {
        destination = .sync
    }
    
    func onImportExport() {
        destination = .importExport
    }
    
    func onTransferItems() {
        destination = .transferItems
    }
    
    func onAbout() {
        destination = .about
    }
    
    func onHelpCenter() {
        destination = .helpCenter
    }
    
    func onDiscord() {
        destination = .discord
    }
    
    func onDebug() {
        destination = .debug
    }
    
    private func refreshAutoFillStatus() {
        autoFillStatus = interactor.isAutoFillEnabled ? String(localized: .commonEnabled) : String(localized: .commonDisabled)
    }
    
    private func refreshPushNotificationsStatus() {
        pushNotificationsStatus = interactor.isPushNotificationsEnabled ? .on : .off
    }
    
    private func refreshSyncStatus(hasError: Bool, isEnabled: Bool) {
        self.syncStatus = {
            guard !hasError else {
                return String(localized: .commonError)
            }
            return isEnabled ? String(localized: .commonEnabled) : String(localized: .commonDisabled)
        }()
        self.hasSyncError = hasError
    }
    
    private func refreshSubscriptionStatus() {
        if interactor.isPaidUser {
            isPaidUser = true
            subscriptionStatus = String(localized: .subscriptionUnlimitedPlan)
        } else {
            isPaidUser = false
            subscriptionStatus = String(localized: .subscriptionFreePlan)
        }
    }
}
