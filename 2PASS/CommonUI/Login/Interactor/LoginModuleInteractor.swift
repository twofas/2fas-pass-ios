// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

public protocol LoginModuleInteracting: AnyObject {
    var lockLogin: (() -> Void)? { get set }
    var unlockLogin: (() -> Void)? { get set }
    
    var loginType: LoginModuleInteractorConfig.LoginType { get }
    
    var prefillMasterPassword: String? { get }
    
    var isBiometryAllowed: Bool { get }
    var isBiometryAvailable: Bool { get }
    var biometryType: BiometryType { get }
    var isAppLocked: Bool { get }
    var appLockRemainingSeconds: Int? { get }
    var hasAppReset: Bool { get }
    var shouldRequestForBiometryToLogin: Bool { get }
    
    func verifyPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping (LoginMasterPasswordResult) -> Void
    )

    func loginUsingBiometry(
        reason: String,
        completion: @escaping (LoginBiometryResult) -> Void
    )
    func resetApp()
    
    func setMasterKey(for masterPassword: MasterPassword)
}

public struct LoginModuleInteractorConfig {
    public enum LoginType: Equatable {
        case login
        case verify(savePassword: Bool)
        case restore
    }
    public let allowBiometrics: Bool
    public let loginType: LoginType
    
    public init(allowBiometrics: Bool, loginType: LoginType) {
        self.allowBiometrics = allowBiometrics
        self.loginType = loginType
    }
}

final class LoginModuleInteractor {
    var lockLogin: (() -> Void)?
    var unlockLogin: (() -> Void)?
    
    var loginType: LoginModuleInteractorConfig.LoginType {
        config.loginType
    }
    
    var hasAppReset: Bool {
        config.loginType == .restore
    }

    private let config: LoginModuleInteractorConfig
    private let loginInteractor: LoginInteracting
    
    init(
        config: LoginModuleInteractorConfig,
        loginInteractor: LoginInteracting
    ) {
        self.config = config
        self.loginInteractor = loginInteractor
        
        loginInteractor.lockLogin = { [weak self] in
            self?.lockLogin?()
        }
        
        loginInteractor.unlockLogin = { [weak self] in
            self?.unlockLogin?()
        }
    }
}

extension LoginModuleInteractor: LoginModuleInteracting {
    var isBiometryAvailable: Bool {
        loginInteractor.canUseBiometryToLogin
    }
    
    var isBiometryAllowed: Bool {
        config.allowBiometrics
    }
    
    var biometryType: BiometryType {
        loginInteractor.biometryType
    }
    
    var appLockRemainingSeconds: Int? {
        loginInteractor.appLockRemainingSeconds
    }
    
    var isAppLocked: Bool {
        loginInteractor.isAppLocked
    }
    
    var prefillMasterPassword: String? {
        loginInteractor.prefillMasterPassword
    }
    
    var shouldRequestForBiometryToLogin: Bool {
        loginInteractor.shouldRequestForBiometryToLogin
    }
    
    func verifyPassword(_ masterPassword: MasterPassword, completion: @escaping (LoginMasterPasswordResult) -> Void) {
        switch config.loginType {
        case .login:
            loginInteractor.loginUsingMasterPassword(masterPassword, completion: completion)
        case .verify(let savePassword):
            loginInteractor.verifyMasterPassword(masterPassword) { [weak self] result in
                switch result {
                case .success:
                    if savePassword {
                        self?.loginInteractor.saveMasterPassword(masterPassword)
                    }
                    completion(result)
                default: completion(result)
                }
            }
        case .restore:
            loginInteractor.verifyMasterPasswordUsingVault(masterPassword) { [weak self] result in
                switch result {
                case .success:
                    self?.loginInteractor.saveMasterPassword(masterPassword)
                    self?.loginInteractor.saveEncryptionReference()
                    completion(result)
                default: completion(result)
                }
            }
        }
    }
    
    func loginUsingBiometry(
        reason: String,
        completion: @escaping (LoginBiometryResult) -> Void
    ) {
        switch config.loginType {
        case .login:
            loginInteractor.loginUsingBiometry(reason: reason, completion: completion)
        case .verify:
            loginInteractor.verifyUsingBiometry(reason: reason, completion: completion)
        case .restore:
            completion(.unavailable)
        }
    }
    
    func resetApp() {
        loginInteractor.resetApp()
    }
    
    func setMasterKey(for masterPassword: MasterPassword) {
        loginInteractor.setMasterKey(for: masterPassword)
    }
}
