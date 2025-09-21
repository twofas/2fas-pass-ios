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
        handleViewFlow()
        fetchAppNotifications()
    }
    
    func applicationDidBecomeActive() {
        Log("App: applicationDidBecomeActive")
        interactor.applicationDidBecomeActive {
            Log("App: Token copied")
        }
        handleViewFlow { [weak self] in
            // so we won't blink between removing cover and bio login
            let longerAnim: Bool = self?.currentState == .login
            self?.removeCover(longerAnim: longerAnim)
        }
    }
    
    func applicationWillResignActive() {
        Log("App: applicationWillResignActive")
        interactor.applicationWillResignActive()

        handleViewFlow()
        installCover()
    }
    
    func applicationDidEnterBackground() {
        Log("App: applicationDidEnterBackground")
        
        toastPresenter.dismissAll(animated: false)
        if interactor.isUserSetUp {
            interactor.logoutFromApp()
            handleViewFlow()
        }
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
        flowController.toRemoveLogin()
        
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
    
    func handleViewFlow(completion: Callback? = nil) {
        Log("RootPresenter: Changing state for: \(currentState)")
        
        Task { @MainActor in
            switch await interactor.start() {
            case .selectVault:
                presentOnboarding()
            case .enterWords:
                presentEnterWords()
            case .login:
                let coldRun = (currentState == .initial)
                presentLogin(coldRun: coldRun)
            case .enterPassword:
                presentEnterPassword()
            case .main:
                presentMain()
            }
            completion?()
        }
    }
    
    // MARK: - Private methods
    private func installCover() {
        guard currentState == .login || currentState == .main else { return }
        flowController.toDismissKeyboard()
        flowController.toCover()
    }
    
    private func removeCover(longerAnim: Bool) {
        flowController.toRemoveCover(delayAnim: longerAnim)
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
        guard currentState != .login else { return }
        changeState(.login)
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
