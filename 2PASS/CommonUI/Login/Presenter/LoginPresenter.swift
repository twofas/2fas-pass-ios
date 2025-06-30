// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

private struct Constants {
    static let appLockTimerInterval: TimeInterval = 0.2
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
    
    var showSplashScreen: Bool {
        interactor.loginType == .login && (coldRun || isBiometryAvailable)
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
    private let coldRun: Bool
    private let loginSuccessful: Callback
    private let appReset: Callback?

    private var lockTimer: Timer?
    
    public init(coldRun: Bool = false, loginSuccessful: @escaping Callback, interactor: LoginModuleInteracting, appReset: Callback? = nil) {
        self.coldRun = coldRun
        self.loginSuccessful = loginSuccessful
        self.interactor = interactor
        self.appReset = appReset
        self.biometryType = interactor.biometryType
        
        interactor.lockLogin = { [weak self] in self?.refreshStatus() }
        interactor.unlockLogin = { [weak self] in self?.refreshStatus() }
        loginInput = interactor.prefillMasterPassword ?? ""
        isBiometryAllowed = interactor.isBiometryAllowed
        hasAppReset = interactor.hasAppReset
    }
}

extension LoginPresenter {
    
    func onAppear() {
        refreshStatus()
    }
    
    public func startBiometryIfAvailable() {
        guard interactor.isAppLocked == false, isBiometryAvailable, isBiometryAllowed, biometryFailed == false, isBiometryScanning == false else { return }
        onBiometry()
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
                self?.loginSuccessful()
                
                if self?.isBiometryAllowed == true
                    && self?.interactor.shouldRequestForBiometryToLogin == true {
                    Task { @MainActor in
                        self?.interactor.setMasterKey(for: loginInput)
                    }
                }
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
