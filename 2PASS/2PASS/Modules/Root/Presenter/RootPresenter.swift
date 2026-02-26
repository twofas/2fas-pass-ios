// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Common
import CommonUI
import Data
import Foundation
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
    private var logoutObservationTask: Task<Void, Never>?
    private var _pendingCredentialData: Any?
    private var currentSceneCaptureState: UISceneCaptureState = .inactive
    private var screenCaptureExpirationTimer: Timer?
    private var screenCaptureAllowanceObserver: NSObjectProtocol?

    @available(iOS 26.0, *)
    private var pendingCredentialData: ASExportedCredentialData? {
        get { _pendingCredentialData as? ASExportedCredentialData }
        set { _pendingCredentialData = newValue }
    }

    init(flowController: RootFlowControlling, interactor: RootModuleInteracting) {
        self.flowController = flowController
        self.interactor = interactor
        self.toastPresenter = .shared
    }

    deinit {
        logoutObservationTask?.cancel()
        screenCaptureExpirationTimer?.invalidate()
        if let screenCaptureAllowanceObserver {
            NotificationCenter.default.removeObserver(screenCaptureAllowanceObserver)
        }
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

        observeLogout()
        observeScreenCaptureAllowanceChanged()
        scheduleScreenCaptureExpirationTimer()
        fetchAppNotifications()
    }

    private func observeLogout() {
        logoutObservationTask = Task { [weak self] in
            guard let self else { return }
            for await _ in interactor.didLogoutApp {
                await MainActor.run { [weak self] in
                    self?.presentLoginIfNeeded()
                }
            }
        }
    }
    
    // MARK: - App flow
    
    func applicationWillEnterForeground() {
        Log("App: applicationWillEnterForeground")
        interactor.applicationWillEnterForeground()
        handleViewFlow()
        fetchAppNotifications()
        scheduleScreenCaptureExpirationTimer()
        evaluateScreenCaptureBlocking()
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

    func applicationContinueUserActivity(_ userActivity: NSUserActivity) -> Bool {
        guard #available(iOS 26.0, *) else { return false }
        return handleCredentialExchangeActivity(userActivity)
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

    func sceneCaptureStateDidChange(_ state: UISceneCaptureState) {
        currentSceneCaptureState = state
        evaluateScreenCaptureBlocking()
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

        if #available(iOS 26.0, *), let data = pendingCredentialData {
            Task { @MainActor in
                pendingCredentialData = nil
                flowController.toCredentialExchange(data: data)
            }
        }
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
    
    @available(iOS 26.0, *)
    private func handleCredentialExchangeActivity(_ userActivity: NSUserActivity) -> Bool {
        guard let token = interactor.extractCredentialExchangeToken(from: userActivity) else {
            return false
        }

        Task { @MainActor in
            do {
                let data = try await interactor.fetchCredentialExchangeData(token: token)
                if currentState == .main {
                    flowController.toCredentialExchange(data: data)
                } else {
                    pendingCredentialData = data
                }
            } catch {
                Log("Failed to fetch credential exchange data: \(error)", module: .moduleInteractor)
            }
        }

        return true
    }

    private func evaluateScreenCaptureBlocking() {
        let shouldBlock = currentSceneCaptureState == .active && !interactor.isScreenCaptureAllowed
        flowController.setScreenCaptureBlocked(shouldBlock)
    }

    private func observeScreenCaptureAllowanceChanged() {
        guard screenCaptureAllowanceObserver == nil else { return }

        screenCaptureAllowanceObserver = NotificationCenter.default.addObserver(
            forName: .screenCaptureAllowanceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateScreenCaptureBlocking()
            self?.scheduleScreenCaptureExpirationTimer()
        }
    }

    private func scheduleScreenCaptureExpirationTimer() {
        screenCaptureExpirationTimer?.invalidate()
        screenCaptureExpirationTimer = nil

        guard let expiration = interactor.screenCaptureAllowedUntil else { return }
        let remaining = expiration.timeIntervalSinceNow
        guard remaining > 0 else {
            interactor.clearScreenCaptureAllowed()
            evaluateScreenCaptureBlocking()
            return
        }

        screenCaptureExpirationTimer = Timer.scheduledTimer(
            withTimeInterval: remaining, repeats: false
        ) { [weak self] _ in
            self?.interactor.clearScreenCaptureAllowed()
            self?.evaluateScreenCaptureBlocking()
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
