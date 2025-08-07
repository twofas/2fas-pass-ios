// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Data

protocol AppSecurityModuleInteracting: AnyObject {
    var lockSection: Callback? { get set }
    var isBiometryEnabled: Bool { get }
    var isBiometryAvailable: Bool { get }
    var limitOfFailedAttempts: AppLockAttempts { get set }
    var defaultSecurityTier: ItemProtectionLevel { get }
    
    func loginUsingBiometryIfAvailable() async -> Bool
    func verifyUsingBiometryIfAvailable() async -> Bool
    func setBiometryEnabled(_ enabled: Bool, result: @escaping (Bool) -> Void)
    func userLoggedIn() -> Bool
    func clearMasterPassword()
}

final class AppSecurityModuleInteractor {
    var lockSection: Callback?
    
    private var isEnablingBiometry = false

    private let loginInteractor: LoginInteracting
    private let biometryInteractor: BiometryInteracting
    private let protectionInteractor: ProtectionInteracting
    private let configInteractor: ConfigInteracting
    private let notificationCenter: NotificationCenter
    
    init(loginInteractor: LoginInteracting, biometryInteractor: BiometryInteracting, protectionInteractor: ProtectionInteracting, configInteractor: ConfigInteracting) {
        self.loginInteractor = loginInteractor
        self.biometryInteractor = biometryInteractor
        self.protectionInteractor = protectionInteractor
        self.configInteractor = configInteractor
        self.notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(
            self,
            selector: #selector(appLock),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
}

extension AppSecurityModuleInteractor: AppSecurityModuleInteracting {
    var isBiometryEnabled: Bool { biometryInteractor.isBiometryEnabled }
    var isBiometryAvailable: Bool { biometryInteractor.isBiometryAvailable }
    
    var defaultSecurityTier: ItemProtectionLevel {
        configInteractor.currentDefaultProtectionLevel
    }
    
    var limitOfFailedAttempts: AppLockAttempts {
        get {
            configInteractor.appLockAttempts
        }
        set {
            configInteractor.setAppLockAttempts(newValue)
        }
    }
    
    func userLoggedIn() -> Bool {
        protectionInteractor.recreateSeedSaltWordsMasterKey()
    }
    
    func verifyUsingBiometryIfAvailable() async -> Bool {
        guard biometryInteractor.canUseBiometryForLogin else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            loginInteractor.verifyUsingBiometry(reason: T.biometryReason) { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                default:
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func loginUsingBiometryIfAvailable() async -> Bool {
        guard biometryInteractor.canUseBiometryForLogin else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            loginInteractor.loginUsingBiometry(reason: T.biometryReason) { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                default:
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func setBiometryEnabled(_ enabled: Bool, result: @escaping (Bool) -> Void) {
        isEnablingBiometry = enabled
        biometryInteractor.setBiometryEnabled(enabled) { [weak self] isEnabled in
            self?.isEnablingBiometry = false
            result(isEnabled)
        }
    }
    
    func clearMasterPassword() {
        protectionInteractor.clearAfterInit()
    }
    
    @objc
    private func appLock() {
        guard !isEnablingBiometry else { return }
        lockSection?()
        protectionInteractor.clearAfterInit()
    }
}
