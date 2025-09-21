// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Data
import UserNotifications

protocol RootModuleInteracting: AnyObject {
    var storageError: ((String) -> Void)? { get set }
    
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
    
    private let rootInteractor: RootInteracting
    private let startupInteractor: StartupInteracting
    private let securityInteractor: SecurityInteracting
    private let syncInteractor: CloudSyncInteracting
    private let appNotificationsInteractor: AppNotificationsInteracting
    private let timeVerificationInteractor: TimeVerificationInteracting
    private let paymentHandlingInteractor: PaymentHandlingInteracting
    private let onboardingInteractor: OnboardingInteracting
    
    init(
        rootInteractor: RootInteracting,
        startupInteractor: StartupInteracting,
        securityInteractor: SecurityInteracting,
        syncInteractor: CloudSyncInteracting,
        appNotificationsInteractor: AppNotificationsInteracting,
        timeVerificationInteractor: TimeVerificationInteracting,
        paymentHandlingInteractor: PaymentHandlingInteracting,
        onboardingInteractor: OnboardingInteracting
    ) {
        self.rootInteractor = rootInteractor
        self.startupInteractor = startupInteractor
        self.securityInteractor = securityInteractor
        self.syncInteractor = syncInteractor
        self.appNotificationsInteractor = appNotificationsInteractor
        self.timeVerificationInteractor = timeVerificationInteractor
        self.paymentHandlingInteractor = paymentHandlingInteractor
        self.onboardingInteractor = onboardingInteractor
        
        rootInteractor.storageError = { [weak self] error in
            self?.storageError?(error)
        }
    }
}

extension RootModuleInteractor: RootModuleInteracting {
    var isOnboardingCompleted: Bool {
        onboardingInteractor.isOnboardingCompleted
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
