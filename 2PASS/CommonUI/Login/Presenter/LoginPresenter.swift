// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common
import Data

private struct Constants {
    static let appLockTimerInterval: TimeInterval = 0.2
    static let showPasswordViewAnimationDuration = 0.3
    static let showPasswordViewAnimationDelay: Duration = .milliseconds(300)
}

@Observable
public final class LoginPresenter {
    
    var loginInput = "" {
        didSet {
            isUnlockAvailable = !interactor.isAppLocked && hasInput
        }
    }
    
    private(set) var errorDescription: String = ""
    private(set) var inputError = false
    private(set) var isUnlockAvailable = false
    private(set) var isBiometryAvailable = false
    private(set) var isBiometryAllowed = false
    private(set) var biometrySuccess = false
    private(set) var biometryFailed = false
    private(set) var biometryType: BiometryType
    private(set) var lockTimeRemaining: Duration?
    private(set) var isBiometryScanning: Bool = false
    private(set) var hasAppReset = false
    private(set) var showSplashScreen = true
    private(set) var isEnterPasswordVisible = false
    private(set) var showKeyboard = false
    
    var showMigrationFailed = false
    
    var showBiometryButton: Bool {
        isBiometryAvailable && isBiometryAllowed
    }
    
    var isAppLocked: Bool {
        lockTimeRemaining != nil
    }
    
    var screenDisabled: Bool {
        isBiometryScanning || isAppLocked
    }
    
    var showCancel: Bool {
        if case .verify = interactor.loginType {
            return true
        }
        return false
    }
    
    var loginType: LoginModuleInteractorConfig.LoginType {
        interactor.loginType
    }
    
    private let interactor: LoginModuleInteracting
    private let notficationCenter: NotificationCenter
    private let coldRun: Bool
    private let loginSuccessful: Callback
    private let appReset: Callback?
    
    private var lockTimer: Timer?
    
    public init(
        coldRun: Bool = false,
        loginSuccessful: @escaping Callback,
        interactor: LoginModuleInteracting,
        appReset: Callback? = nil
    ) {
        self.coldRun = coldRun
        self.loginSuccessful = loginSuccessful
        self.interactor = interactor
        self.appReset = appReset
        self.biometryType = interactor.biometryType
        self.notficationCenter = .default
                
        interactor.lockLogin = { [weak self] in self?.refreshStatus() }
        interactor.unlockLogin = { [weak self] in self?.refreshStatus() }
        loginInput = interactor.prefillMasterPassword ?? ""
        isBiometryAllowed = interactor.isBiometryAllowed
        isBiometryAvailable = interactor.isBiometryAvailable
        hasAppReset = interactor.hasAppReset
        
        if case .login = loginType {
            notficationCenter
                .addObserver(
                    self,
                    selector: #selector(willEnterForegroundNotification),
                    name: UIApplication.willEnterForegroundNotification,
                    object: nil
                )
            
            notficationCenter
                .addObserver(
                    self,
                    selector: #selector(didBecomeActiveNotification),
                    name: UIApplication.didBecomeActiveNotification,
                    object: nil
                )
        }
        
        if coldRun, UIApplication.shared.applicationState == .active {
            didBecomeActiveNotification()
        }
    }
    
    deinit {
        notficationCenter.removeObserver(self)
    }
}

extension LoginPresenter {
    
    // Called from AutoFill extension
    public func startBiometryIfAvailable() {
        guard interactor.isAppLocked == false,
              isBiometryAvailable,
                isBiometryAllowed,
                biometryFailed == false,
                isBiometryScanning == false else { return }
        onBiometry()
    }
    
    func onAppear() {
        if interactor.isUserLoggedIn {
            showSplashScreen = false
            isEnterPasswordVisible = true
            showKeyboard = true
        } else {
            guard isBiometryScanning == false else { return }
            isBiometryAvailable = interactor.isBiometryAvailable
            
            if canUseBiometry {
                showSplashScreen = true
            } else if coldRun {
                Task { @MainActor in
                    try await Task.sleep(for: Constants.showPasswordViewAnimationDelay)
                    
                    withAnimation(.smooth(duration: Constants.showPasswordViewAnimationDuration)) {
                        showSplashScreen = false
                    }

                    withAnimation(.easeInOut(duration: Constants.showPasswordViewAnimationDuration)) {
                        isEnterPasswordVisible = true
                    }
                }
            } else {
                showSplashScreen = false
                isEnterPasswordVisible = true
            }
            
            startLockTimerIfNeeded()
        }
    }
    
    @objc
    func willEnterForegroundNotification() {
        biometryFailed = false
        showKeyboard = false
    }
    
    @objc
    func didBecomeActiveNotification() {
        isBiometryAvailable = interactor.isBiometryAvailable
        
        startLockTimerIfNeeded()
        
        if canUseBiometry {
            if biometrySuccess == false, isBiometryScanning == false {
                onBiometry()
            }
        } else if coldRun {
            Task { @MainActor in
                showKeyboard = true
            }
        } else {
            showKeyboard = true
        }
    }
    
    private var canUseBiometry: Bool {
        interactor.loginType == .login
            && isBiometryAvailable
            && !interactor.isAppLocked
            && interactor.isBiometryAllowed
            && biometryFailed == false
    }
    
    func onLogin() {
        guard hasInput else {
            return
        }
        
        inputError = false
        
        let loginInput = self.loginInput
        
        interactor.verifyPassword(loginInput) { [weak self] result in
            switch result {
            case .success:
                self?.showKeyboard = false
                self?.loginInput = ""
                
                if self?.isBiometryAllowed == true
                    && self?.interactor.shouldRequestForBiometryToLogin == true {
                    Task { @MainActor in
                        self?.interactor.setMasterKey(for: loginInput)
                    }
                }
                
                self?.loginSuccessful()
            case .appLocked:
                self?.loginInput = ""
                self?.refreshStatus()
            case .invalidPassword:
                self?.refreshStatus()
                
                Task { @MainActor in
                    self?.errorDescription = T.lockScreenUnlockInvalidPassword
                    self?.inputError = true
                }
            case .invalidPasswordAppLocked:
                self?.loginInput = ""
                self?.refreshStatus()
            }
        }
    }
    
    func onBiometry() {
        isBiometryScanning = true
        biometryFailed = false
        interactor.loginUsingBiometry(reason: T.lockScreenUnlockBiometricsReason) { [weak self] result in
            self?.isBiometryScanning = false
            
            switch result {
            case .success:
                self?.biometrySuccess = true
                self?.loginSuccessful()
            case .failure, .unavailable:
                self?.biometryFailed = true
                self?.errorDescription = T.lockScreenUnlockBiometricsError
                self?.refreshStatus()
            case .appLocked:
                self?.loginInput = ""
                self?.errorDescription = ""
                self?.refreshStatus()
            }
        }
    }
    
    func onAppReset() {
        interactor.resetApp()
        appReset?()
    }
    
    func onMigrationFailedClose() {
        loginSuccessful()
    }
}

private extension LoginPresenter {
    
    var hasInput: Bool {
        loginInput.count >= Config.minMasterPasswordLength
    }
    
    func refreshStatus() {
        isBiometryAvailable = interactor.isBiometryAvailable
        inputError = false
        errorDescription = ""

        if canUseBiometry == false {
            withAnimation(.smooth(duration: Constants.showPasswordViewAnimationDuration)) {
                showSplashScreen = false
            } completion: { [weak self] in
                self?.showKeyboard = true
            }
            
            withAnimation(.easeInOut(duration: Constants.showPasswordViewAnimationDuration)) {
                isEnterPasswordVisible = true
            }
        }
        
        startLockTimerIfNeeded()
    }
    
    private func startLockTimerIfNeeded() {
        if lockTimer == nil, interactor.isAppLocked {
            startLockTimer()
        }
    }
    
    private func startLockTimer() {
        lockTimer = Timer.scheduledTimer(withTimeInterval: Constants.appLockTimerInterval, repeats: true) { [weak self] timer in
            if let seconds = self?.interactor.appLockRemainingSeconds {
                self?.lockTimeRemaining = Duration.seconds(seconds)
            } else {
                self?.lockTimeRemaining = nil
            }
        }
    }
}
