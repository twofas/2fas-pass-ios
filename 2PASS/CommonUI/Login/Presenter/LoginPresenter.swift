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
    static let showPasswordViewAnimationDelay = 0.4
}

@Observable
public final class LoginPresenter {
    
    var loginInput = "" {
        didSet {
            refreshStatus()
        }
    }
    
    private(set) var errorDescription: String = ""
    private(set) var inputError = false
    private(set) var isUnlockAvailable = false
    private(set) var isBiometryAvailable = false
    private(set) var isBiometryAllowed = false
    private(set) var biometryFailed = false
    private(set) var biometryType: BiometryType
    private(set) var lockTimeRemaining: Duration?
    private(set) var isBiometryScanning: Bool = false
    private(set) var hasAppReset = false
    private(set) var showSplashScreen = true
    private(set) var isEnterPasswordVisible = false
    private(set) var showKeyboard = false
    
    var showMigrationFailed = false
    var hideKeyboard: Callback?
    
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
        notficationCenter
            .addObserver(
                self,
                selector: #selector(onAppear),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        
        interactor.lockLogin = { [weak self] in self?.refreshStatus() }
        interactor.unlockLogin = { [weak self] in self?.refreshStatus() }
        loginInput = interactor.prefillMasterPassword ?? ""
        isBiometryAllowed = interactor.isBiometryAllowed
        hasAppReset = interactor.hasAppReset
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
    
    @objc
    func onAppear() { // this method is called multiple times, but should run once
        guard !interactor.isUserLoggedIn && !isBiometryScanning else { return }
        refreshStatus()
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
                self?.hideKeyboard?()
                
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
                self?.showSplashScreen = true
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
        isUnlockAvailable = !interactor.isAppLocked && hasInput
        isBiometryAvailable = interactor.isBiometryAvailable
        inputError = false
        errorDescription = ""
        
        // we're showing Login screen when going into background, but biometry shouldn't run
        guard UIApplication.shared.applicationState == .active else {
            showSplashScreen = true
            isEnterPasswordVisible = false
            return
        }
        
        if interactor.loginType == .login
            && (coldRun || isBiometryAvailable)
            && !interactor.isAppLocked
            && interactor.isBiometryAllowed
            && biometryFailed == false {
            showSplashScreen = true
            isEnterPasswordVisible = false
            if isBiometryScanning == false {
                onBiometry()
            }
        } else {
            withAnimation(.easeInOut(duration: Constants.showPasswordViewAnimationDuration)
                .delay(Constants.showPasswordViewAnimationDelay)) {
                showSplashScreen = false
                isEnterPasswordVisible = true
            } completion: { [weak self] in
                self?.showKeyboard = true
            }
        }
        
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
