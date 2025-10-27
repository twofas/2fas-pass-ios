// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Data
import UserNotifications
import Foundation

protocol RootModuleInteracting: AnyObject {
    var storageError: ((String) -> Void)? { get set }
    var presentAppUpdateNeededForNewSyncSchema: ((Int) -> Void)? { get set }
    
    var appVersionPromptState: UpdateAppPromptState { get }
    func markAppVersionPromptAsShown()
    
    var isUserSetUp: Bool { get }
    var isOnboardingCompleted: Bool { get }
        
    func isBackupFileURL(_ url: URL) -> Bool
    
    func initializeApp()
    func applicationWillResignActive()
    func applicationWillEnterForeground()
    func applicationDidBecomeActive(didCopyToken: @escaping Callback)
    func applicationWillTerminate()
        
    func logoutFromApp()
    
    func start() async -> StartupInteractorStartResult
    
    func handleRemoteNotification()
    func handleDidReceiveRegistrationToken(_ token: String?)
    
    func isConnectNotification(userInfo: [AnyHashable: Any]) -> Bool
    func fetchAppNotifications() async throws -> [AppNotification]
}

final class RootModuleInteractor {
    var storageError: ((String) -> Void)?
    var presentAppUpdateNeededForNewSyncSchema: ((Int) -> Void)?
    
    private let rootInteractor: RootInteracting
    private let startupInteractor: StartupInteracting
    private let securityInteractor: SecurityInteracting
    private let syncInteractor: CloudSyncInteracting
    private let appNotificationsInteractor: AppNotificationsInteracting
    private let timeVerificationInteractor: TimeVerificationInteracting
    private let paymentHandlingInteractor: PaymentHandlingInteracting
    private let onboardingInteractor: OnboardingInteracting
    private let updateAppPromptInteractor: UpdateAppPromptInteracting
    private let notificationCenter = NotificationCenter.default
    
    init(
        rootInteractor: RootInteracting,
        startupInteractor: StartupInteracting,
        securityInteractor: SecurityInteracting,
        syncInteractor: CloudSyncInteracting,
        appNotificationsInteractor: AppNotificationsInteracting,
        timeVerificationInteractor: TimeVerificationInteracting,
        paymentHandlingInteractor: PaymentHandlingInteracting,
        onboardingInteractor: OnboardingInteracting,
        updateAppPromptInteractor: UpdateAppPromptInteracting
    ) {
        self.rootInteractor = rootInteractor
        self.startupInteractor = startupInteractor
        self.securityInteractor = securityInteractor
        self.syncInteractor = syncInteractor
        self.appNotificationsInteractor = appNotificationsInteractor
        self.timeVerificationInteractor = timeVerificationInteractor
        self.paymentHandlingInteractor = paymentHandlingInteractor
        self.onboardingInteractor = onboardingInteractor
        self.updateAppPromptInteractor = updateAppPromptInteractor
        
        rootInteractor.storageError = { [weak self] error in
            self?.storageError?(error)
        }
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleShowUpdatePromptNotification(_:)),
            name: .showUpdateAppPrompt,
            object: nil
        )
    }
}

extension RootModuleInteractor: RootModuleInteracting {
    
    var isOnboardingCompleted: Bool {
        onboardingInteractor.isOnboardingCompleted
    }
    
    var appVersionPromptState: UpdateAppPromptState {
        updateAppPromptInteractor.appVersionPromptState
    }
    
    func markAppVersionPromptAsShown() {
        updateAppPromptInteractor.markPromptAsShown()
    }
    
    var isUserSetUp: Bool {
        startupInteractor.isUserSetUp
    }
    
    func initializeApp() {
        Log("RootModuleInteractor: Initialize app", module: .moduleInteractor)
        startupInteractor.initialize()
        rootInteractor.initializeApp()
        UIApplication.shared.registerForRemoteNotifications()
        timeVerificationInteractor.startVerification()
        paymentHandlingInteractor.initialize()
    }
    
    @MainActor
    func start() async -> StartupInteractorStartResult {
        await startupInteractor.start()
    }
    
    func logoutFromApp() {
        rootInteractor.lockApplication()
    }
    
    func applicationWillResignActive() {
        rootInteractor.applicationWillResignActive()
    }
    
    func applicationWillEnterForeground() {
        rootInteractor.applicationWillEnterForeground()
        timeVerificationInteractor.startVerification()
    }
    
    func applicationWillTerminate() {
        rootInteractor.applicationWillTerminate()
    }
    
    func applicationDidBecomeActive(didCopyToken: @escaping Callback) {
        rootInteractor.applicationDidBecomeActive()
    }
    
    func handleRemoteNotification() {
        guard securityInteractor.isUserLoggedIn && isUserSetUp else {
            return
        }
        syncInteractor.synchronize()
    }
    
    func fetchAppNotifications() async throws -> [AppNotification] {
        try await appNotificationsInteractor.fetchAppNotifications()
    }

    func handleDidReceiveRegistrationToken(_ token: String?) {
        rootInteractor.handleDidReceiveRegistrationToken(token)
    }
    
    func isConnectNotification(userInfo: [AnyHashable : Any]) -> Bool {
        if let messageType = userInfo["messageType"] as? String, messageType == "be_request" {
            return true
        } else {
            return false
        }
    }
    
    func isBackupFileURL(_ url: URL) -> Bool {
        url.pathExtension == "2faspass"
    }
}

private extension RootModuleInteractor {
    
    @objc func handleShowUpdatePromptNotification(_ notification: Notification) {
        guard let reason = notification.userInfo?[Notification.showUpdateAppPromptReasonKey] as? UpdateAppPromptRequestReason else {
            return
        }
        
        switch reason {
        case .webDAVSchemeNotSupported(let schemaVersion):
            presentAppUpdateNeededForNewSyncSchema?(schemaVersion)
        case .iCloudSchemeNotSupported(let schemaVersion):
            presentAppUpdateNeededForNewSyncSchema?(schemaVersion)
        }
    }
}
