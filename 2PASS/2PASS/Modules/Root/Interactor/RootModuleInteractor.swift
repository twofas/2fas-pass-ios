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
    var introductionWasShown: Bool { get }
    var storageError: ((String) -> Void)? { get set }
    
    var isUserLoggedIn: Bool { get }
    var isUserSetUp: Bool { get }
    var canLockApp: Bool { get }
    
    var shouldRequestForBiometryToLogin: Bool { get }
    
    func isBackupFileURL(_ url: URL) -> Bool
    
    func initializeApp()
    func applicationWillResignActive()
    func applicationWillEnterForeground()
    func applicationDidBecomeActive(didCopyToken: @escaping Callback)
    func applicationWillTerminate()
        
    func lockApplication()
            
    func lockScreenActive()
    func lockScreenInactive()
    
    func start() -> StartupInteractorStartResult
    
    func handleRemoteNotification()
    func handleDidReceiveRegistrationToken(_ token: String?)
    
    func isConnectNotification(userInfo: [AnyHashable: Any]) -> Bool
    func fetchAppNotifications() async throws -> [AppNotification]
}

final class RootModuleInteractor {
    var storageError: ((String) -> Void)?
    
    private let rootInteractor: RootInteracting
    private let appStateInteractor: AppStateInteracting
    private let startupInteractor: StartupInteracting
    private let securityInteractor: SecurityInteracting
    private let loginInteractor: LoginInteracting
    private let syncInteractor: CloudSyncInteracting
    private let appNotificationsInteractor: AppNotificationsInteracting
    private let timeVerificationInteractor: TimeVerificationInteracting
    private let paymentHandlingInteractor: PaymentHandlingInteracting
    
    init(
        rootInteractor: RootInteracting,
        appStateInteractor: AppStateInteracting,
        startupInteractor: StartupInteracting,
        securityInteractor: SecurityInteracting,
        loginInteractor: LoginInteracting,
        syncInteractor: CloudSyncInteracting,
        appNotificationsInteractor: AppNotificationsInteracting,
        timeVerificationInteractor: TimeVerificationInteracting,
        paymentHandlingInteractor: PaymentHandlingInteracting
    ) {
        self.rootInteractor = rootInteractor
        self.appStateInteractor = appStateInteractor
        self.startupInteractor = startupInteractor
        self.securityInteractor = securityInteractor
        self.loginInteractor = loginInteractor
        self.syncInteractor = syncInteractor
        self.appNotificationsInteractor = appNotificationsInteractor
        self.timeVerificationInteractor = timeVerificationInteractor
        self.paymentHandlingInteractor = paymentHandlingInteractor
        
        rootInteractor.storageError = { [weak self] error in
            self?.storageError?(error)
        }
    }
}

extension RootModuleInteractor: RootModuleInteracting {
    
    var shouldRequestForBiometryToLogin: Bool {
        loginInteractor.shouldRequestForBiometryToLogin
    }
    
    var canLockApp: Bool {
        securityInteractor.canLockApp
    }
    
    var isUserLoggedIn: Bool {
        securityInteractor.isUserLoggedIn
    }
    
    var introductionWasShown: Bool {
        rootInteractor.introductionWasShown
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
    
    func start() -> StartupInteractorStartResult {
        startupInteractor.start()
    }
    
    func lockApplication() {
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
        
    func lockScreenActive() {
        appStateInteractor.lockScreenActive()
    }
    
    func lockScreenInactive() {
        appStateInteractor.lockScreenInactive()
    }
    
    func handleRemoteNotification() {
        guard isUserLoggedIn && isUserSetUp else {
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
