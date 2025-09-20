// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data
import CommonUI
import UIKit

final class RootPresenter {
    fileprivate enum State {
        case initial
        case login
        case onboarding
        case enterPassword
        case enterWords
        case recoveryKit
        case main
    }
    
    private var currentState = State.initial {
        didSet {
            Log("RootPresenter: new currentState: \(currentState)")
        }
    }
    
    private var isCoverActive = false
    
    private let flowController: RootFlowControlling
    private let interactor: RootModuleInteracting
    private let toastPresenter: ToastPresenter
    private var appNotificationsQueue: [AppNotification] = []
    
    init(flowController: RootFlowControlling, interactor: RootModuleInteracting) {
        self.flowController = flowController
        self.interactor = interactor
        self.toastPresenter = .shared
    }
    
    func initialize() {
        interactor.initializeApp()
        interactor.storageError = { [weak self] error in
            self?.flowController.toStorageError(error: error)
        }
        handleViewFlow()
        fetchAppNotifications()
    }
    
    // MARK: - App flow
    
    func applicationWillEnterForeground() {
        Log("App: applicationWillEnterForeground")
        interactor.applicationWillEnterForeground()
        removeCover()
        handleViewFlow()
        fetchAppNotifications()
    }
    
    func applicationDidBecomeActive() {
        Log("App: applicationDidBecomeActive")
        interactor.applicationDidBecomeActive {
            Log("App: Token copied")
        }
        removeCover(animated: true)
        toLogin()
    }
    
    func applicationWillResignActive() {
        Log("App: applicationWillResignActive")
        interactor.applicationWillResignActive()
        
        if interactor.isUserSetUp && interactor.canLockApp {
            installCover()
        }
    }
    
    func applicationDidEnterBackground() {
        Log("App: applicationDidEnterBackground")
        
        toastPresenter.dismissAll(animated: false)
        
        interactor.lockApplication()
        removeCover()
        toLogin()
    }
    
    func applicationWillTerminate() {
        Log("App: applicationWillTerminate")
        interactor.applicationWillTerminate()
    }
    
    func applicationOpenURL(_ url: URL) -> Bool {
        Log("App: applicationOpenURL")
        if interactor.isUserSetUp, interactor.isBackupFileURL(url) {
            flowController.toOpenExternalFileError()
            return true
        }
        return false
    }
    
    // MARK: - Handle external events
    
    func handleAppReset() {
        handleViewFlow()
    }
    
    func handleUserWasLoggedIn() {
        flowController.toDismissKeyboard()
        handleViewFlow()
        
        if let newestNotification = appNotificationsQueue.last {
            flowController.toAppNotification(newestNotification)
        }
    }
    
    func handleWordsEntered() {
        handleViewFlow()
    }
    
    // MARK: - Notifications
    
    func handleRemoteNotification(userInfo: [AnyHashable: Any]) {
        interactor.handleRemoteNotification()
        
        if interactor.isConnectNotification(userInfo: userInfo) {
            Task { @MainActor in
                let notifications = try await interactor.fetchAppNotifications()
                appNotificationsQueue = notifications
                
                showAppNotificationIfNeeded()
            }
        }
    }
    
    func handleDidReceiveRegistrationToken(_ token: String?) {
        interactor.handleDidReceiveRegistrationToken(token)
    }
    
    // MARK: - RootCoordinatorDelegate methods
    
    func handleViewFlow() {
        let coldRun = (currentState == .initial)
        
        Log("RootPresenter: Changing state for: \(currentState)")
        if interactor.isUserLoggedIn && interactor.isOnboardingCompleted && interactor.isUserSetUp {
            presentMain()
        } else {
            Task { @MainActor in
                switch await interactor.start() {
                case .selectVault:
                    presentOnboarding()
                case .enterWords:
                    presentEnterWords()
                case .login:
                    presentLogin(coldRun: coldRun)
                case .enterPassword:
                    presentEnterPassword()
                }
            }
        }
    }
    
    // MARK: - Private methods
    
    private func toLogin(coldRun: Bool = false) {
        if !interactor.isUserLoggedIn && interactor.isUserSetUp { // onboarding???
            presentLogin(coldRun: coldRun)
        }
    }
    
    private func installCover() {
        guard currentState != .login else { return }
        flowController.toDismissKeyboard()
        isCoverActive = true
        flowController.toCover()
    }
    
    private func removeCover(animated: Bool = false) {
        guard isCoverActive else { return }
        isCoverActive = false
        guard  currentState != .login else { return }
        flowController.toRemoveCover(animated: animated)
    }
    
    private func presentOnboarding() {
        guard currentState != .onboarding else { return }
        changeState(.onboarding)
        flowController.toOnboarding()
    }
    
    private func presentEnterPassword() {
        guard currentState != .enterPassword else { return }
        changeState(.enterPassword)
        flowController.toEnterPassword()
    }
    
    private func presentEnterWords() {
        guard currentState != .enterWords else { return }
        changeState(.enterWords)
        flowController.toEnterWords()
    }
    
    private func presentMain() {
        guard currentState != .main else { return }
        changeState(.main)
        flowController.toMain()
    }
    
    private func presentLogin(coldRun: Bool) {
        if currentState != .login {  // != else return!
            changeState(.login)
        }
        Log("Presenting Login")
        flowController.toLogin(coldRun: coldRun)
    }
    
    private func changeState(_ newState: State) {
        currentState = newState
    }
    
    private func fetchAppNotifications() {
        Task { @MainActor in
            let notifications = try await interactor.fetchAppNotifications()
            appNotificationsQueue = notifications
        }
    }
    
    private func showAppNotificationIfNeeded() {
        if let newestNotification = appNotificationsQueue.last {
            if currentState == .main {
                flowController.toAppNotification(newestNotification)
            }
        }
    }
}

extension LogMessage.Interpolation {
    
    fileprivate mutating func appendInterpolation(_ value: @autoclosure () -> RootPresenter.State, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
}
