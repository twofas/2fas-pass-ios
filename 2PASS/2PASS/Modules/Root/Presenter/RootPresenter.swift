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

private struct Constants {
    static let showUpdateAppPromptDelay: Duration = .milliseconds(500)
}

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
        flowController.toCover() // add a splash screen for the time between app launch and startup completion.

        interactor.initializeApp()
        interactor.storageError = { [weak self] error in
            self?.flowController.toStorageError(error: error)
        }
        
        handleViewFlow { [weak self] in
            self?.flowController.toRemoveCover()
        }

        interactor.presentAppUpdateNeededForNewSyncSchema = { [weak self] schemaVersion in
            self?.flowController.toUpdateAppForNewSyncScheme(schemaVersion: schemaVersion)
            self?.interactor.markAppVersionPromptAsShown()
        }

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
    }
    
    func applicationWillResignActive() {
        Log("App: applicationWillResignActive")
        interactor.applicationWillResignActive()
    }
    
    func applicationDidEnterBackground() {
        Log("App: applicationDidEnterBackground")
        
        toastPresenter.dismissAll(animated: false)
        
        if interactor.isUserSetUp {
            interactor.logoutFromApp()
            presentLoginIfNeeded()
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
        handleViewFlow { [weak self] in
            if self?.currentState != .login {
                self?.flowController.toRemoveLogin()
            }
        }
        
        if let newestNotification = appNotificationsQueue.last {
            flowController.toAppNotification(newestNotification)
        }
        
        showAppNotificationIfNeeded()
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
            let result = await interactor.start()
            switch result {
            case .selectVault:
                presentOnboarding()
            case .enterWords:
                presentRestoreVault()
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
    
    private func presentLoginIfNeeded() {
        guard currentState == .login || currentState == .main else { return }
        flowController.toDismissKeyboard()
        flowController.toLogin(coldRun: false)
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
    
    private func presentRestoreVault() {
        guard currentState != .enterWords else { return }
        changeState(.enterWords)
        flowController.toRestoreVault()
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
        } else {
            switch interactor.appVersionPromptState {
            case .unsupportedAppVersion(let minimalVersion):
                Task { @MainActor in
                    try await Task.sleep(for: Constants.showUpdateAppPromptDelay)

                    flowController.toUpdateAppForUnsupportedVersion(minimalVersion: minimalVersion)
                    interactor.markAppVersionPromptAsShown()
                }
            default:
                break
            }
        }
    }
}

extension LogMessage.Interpolation {
    
    fileprivate mutating func appendInterpolation(_ value: @autoclosure () -> RootPresenter.State, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
}
