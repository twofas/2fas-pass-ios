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
        case vaultRecovery
        case enterPassword
        case enterWords
        case recoveryKit
        case intro
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
        interactor.presentAppUpdateNeededForNewSyncSchema = { [weak self] schemaVersion in
            self?.flowController.toUpdateAppForNewSyncScheme(schemaVersion: schemaVersion)
            self?.interactor.markAppVersionPromptAsShown()
        }
        handleViewFlow(canUseBiometry: false)
        fetchAppNotifications()
    }
    
    func applicationWillResignActive() {
        Log("App: applicationWillResignActive")
        interactor.applicationWillResignActive()
        
        if interactor.isUserSetUp && interactor.canLockApp {
            interactor.lockScreenActive()
            installCover()
        }
    }
    
    func applicationDidEnterBackground() {
        Log("App: applicationDidEnterBackground")
        
        toastPresenter.dismissAll(animated: false)
        
        interactor.lockApplication()
        removeCover()
        toLogin(canUseBiometry: false)
    }
    
    func applicationWillEnterForeground() {
        Log("App: applicationWillEnterForeground")
        lockScreenIsInactive()
        interactor.applicationWillEnterForeground()
        removeCover()
        handleViewFlow(canUseBiometry: false)
        fetchAppNotifications()
    }
    
    func applicationDidBecomeActive() {
        Log("App: applicationDidBecomeActive")
        lockScreenIsInactive()
        interactor.applicationDidBecomeActive {
            Log("App: Token copied")
        }
        removeCover(animated: true)
        toLogin()
        //        view?.rateApp()
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
    
    func handleIntroHasFinished() {
        handleViewFlow()
    }
    
    func handleAppReset() {
        handleViewFlow()
    }
    
    func handleUserWasLoggedIn() {
        flowController.toDismissKeyboard()
        interactor.lockScreenInactive()
        handleViewFlow()
        
        showAppNotificationIfNeeded()
        
        if interactor.shouldRequestForBiometryToLogin {
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(700))
                flowController.toRequestEnableBiometry()
            }
        }
    }
    
    func handleWordsEntered() {
        handleViewFlow()
    }
    
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
    
    func handleViewFlow(canUseBiometry: Bool = true) {
        let coldRun = (currentState == .initial)
        
        Log("RootPresenter: Changing state for: \(currentState)")
        if interactor.isUserLoggedIn {
            presentMain(immediately: coldRun)
        } else {
            switch interactor.start() {
            case .selectVault:
                presentVaultRecovery()
            case .enterWords:
                presentEnterWords()
            case .login:
                presentLogin(coldRun: coldRun, canUseBiometry: canUseBiometry)
            case .enterPassword:
                presentEnterPassword()
            }
        }
    }
    
    // MARK: - Private methods
    
    private func toLogin(coldRun: Bool = false, canUseBiometry: Bool = true) {
        if !interactor.isUserLoggedIn && interactor.isUserSetUp {
            presentLogin(coldRun: coldRun, canUseBiometry: canUseBiometry)
        }
    }
    
    private func lockScreenIsInactive() {
        if currentState == .main {
            interactor.lockScreenInactive()
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
    
    private func presentVaultRecovery() {
        guard currentState != .vaultRecovery else { return }
        changeState(.vaultRecovery)
        Log("Presenting Vault Recovery")
        flowController.toVaultRecovery()
    }
    
    private func presentEnterPassword() {
        guard currentState != .enterPassword else { return }
        changeState(.enterPassword)
        Log("Presenting Enter Password")
        flowController.toEnterPassword()
    }
    
    private func presentEnterWords() {
        guard currentState != .enterWords else { return }
        changeState(.enterWords)
        Log("Presenting Enter Words")
        flowController.toEnterWords()
    }
    
    private func presentMain(immediately: Bool) {
        guard currentState != .main else { return }
        let immediately = !(currentState == .login || currentState == .intro)
        changeState(.main)
        Log("Presenting Main")
        flowController.toMain(immediately: immediately)
    }
    
    private func presentLogin(coldRun: Bool, canUseBiometry: Bool) {
        if currentState != .login {
            changeState(.login)
            
            interactor.lockScreenActive()
        }
        Log("Presenting Login")
        flowController.toLogin(coldRun: coldRun, canUseBiometry: canUseBiometry)
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
