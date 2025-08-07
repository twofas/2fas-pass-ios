// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

enum AppSecurityRouteDestination: RouterDestination {
    case changePassword(onResult: (Result<Void, Error>) -> Void)
    case defaultSecurityTier
    case currentPassword(config: LoginModuleInteractorConfig, onSuccess: Callback)
    case limitOfFailedAttempts(picker: SettingsPicker<AppLockAttempts>)
    case vaultDecryptionKit(onFinish: Callback)
    
    var id: String {
        switch self {
        case .changePassword: "changePassword"
        case .currentPassword: "currentPassword"
        case .limitOfFailedAttempts: "limitOfFailedAttempts"
        case .defaultSecurityTier: "defaultSecurityTier"
        case .vaultDecryptionKit: "vaultDecryptionKit"
        }
    }
}

private struct Constants {
    static let pushDelayAfterCurrentPassword: Duration = .milliseconds(600) // Starting a push after a modal dismiss sets the destination to nil.
    static let enablingBiometryDelayAfterCurrentPassword: Duration = .milliseconds(600)
}

@Observable
final class AppSecurityPresenter {
    var lockInteraction = false
    var destination: AppSecurityRouteDestination? {
        didSet {
            DispatchQueue.main.async {
                self.lockInteraction = false
            }
        }
    }
    
    var isBiometryEnabled: Bool {
        get {
            interactor.isBiometryEnabled
        }
        set {
            guard interactor.isBiometryEnabled != newValue else {
                return
            }
            
            if newValue {
                turnOnBiometry()
            } else {
                turnOffBiometry()
            }
        }
    }
    
    private(set) var isBiometryAvailable = false
    private(set) var enableBiometryToggle = false

    private var limitOfFailedAttempts: AppLockAttempts {
        didSet {
            interactor.limitOfFailedAttempts = limitOfFailedAttempts
        }
    }
    private(set) var defaultSecurityTier: ItemProtectionLevel
    
    private let interactor: AppSecurityModuleInteracting
    
    init(interactor: AppSecurityModuleInteracting) {
        self.interactor = interactor
        
        limitOfFailedAttempts = interactor.limitOfFailedAttempts
        defaultSecurityTier = interactor.defaultSecurityTier
    }
}

extension AppSecurityPresenter {
    
    func onAppear() {
        isBiometryAvailable = interactor.isBiometryAvailable
        enableBiometryToggle = true
        defaultSecurityTier = interactor.defaultSecurityTier
        
        interactor.clearMasterPassword()
    }
    
    func onLimitOfFailedAttempts() {
        guard !lockInteraction else { return }
        lockInteraction = true

        Task { @MainActor in
            if await interactor.verifyUsingBiometryIfAvailable() {
                showLimitedOfFailedAttemptsPicker()
            } else {
                destination = .currentPassword(config: .init(allowBiometrics: true, loginType: .verify(savePassword: false)), onSuccess: { [weak self] in
                    self?.destination = nil
                    
                    Task { @MainActor in
                        try await Task.sleep(for: Constants.pushDelayAfterCurrentPassword)
                        self?.showLimitedOfFailedAttemptsPicker()
                    }
                })
            }
        }
    }
    
    func onDefaultSecurityTier() {
        guard !lockInteraction else { return }
        lockInteraction = true
        
        destination = .defaultSecurityTier
    }
    
    func onChangePassword() {
        guard !lockInteraction else { return }
        lockInteraction = true
        
        destination = .currentPassword(config: .init(allowBiometrics: false, loginType: .verify(savePassword: true)), onSuccess: { [weak self] in
            self?.destination = nil
            
            Task { @MainActor in
                try await Task.sleep(for: Constants.pushDelayAfterCurrentPassword)
                self?.destination = .changePassword(onResult: { _ in
                    self?.interactor.clearMasterPassword()
                    self?.destination = nil
                })
            }
        })
    }
    
    func onVaultDecryptionKit() {
        guard !lockInteraction else { return }
        lockInteraction = true
        
        destination = .currentPassword(config: .init(allowBiometrics: false, loginType: .verify(savePassword: true)), onSuccess: { [weak self] in
            self?.destination = nil
            
            if self?.interactor.userLoggedIn() == true {
                Task { @MainActor in
                    try await Task.sleep(for: Constants.pushDelayAfterCurrentPassword)
                    self?.destination = .vaultDecryptionKit(onFinish: {
                        self?.interactor.clearMasterPassword()
                        self?.destination = nil
                    })
                }
            } else {
                self?.interactor.clearMasterPassword()
            }
        })
    }
}

private extension AppSecurityPresenter {
    
    func turnOnBiometry() {
        guard !lockInteraction else { return }
        lockInteraction = true
        
        destination = .currentPassword(config: .init(allowBiometrics: false, loginType: .verify(savePassword: true)), onSuccess: { [weak self] in
            self?.destination = nil

            if self?.interactor.userLoggedIn() == true {
                Task { @MainActor in
                    try await Task.sleep(for: Constants.enablingBiometryDelayAfterCurrentPassword)
                    self?.performUpdateBiometryState()
                }
            } else {
                self?.interactor.clearMasterPassword()
            }
        })
    }
    
    func turnOffBiometry() {
        interactor.setBiometryEnabled(false) { result in
        }
    }
    
    func performUpdateBiometryState() {
        guard isBiometryAvailable && enableBiometryToggle else {
            interactor.clearMasterPassword()
            return
        }
        enableBiometryToggle = false
        interactor.setBiometryEnabled(true) { [weak self] result in
            self?.isBiometryEnabled = result
            self?.enableBiometryToggle = true
            self?.interactor.clearMasterPassword()
        }
    }
    
    func showLimitedOfFailedAttemptsPicker() {
        destination = .limitOfFailedAttempts(picker: .init(
            options: AppLockAttempts.allCases,
            selected: Binding {
                self.limitOfFailedAttempts
            } set: {
                if let newValue = $0 {
                    self.limitOfFailedAttempts = newValue
                }
            },
            formatter: {
                switch $0 {
                case .try3: T.lockoutSettingsAppLockAttemptsCount3
                case .try5: T.lockoutSettingsAppLockAttemptsCount5
                case .try10: T.lockoutSettingsAppLockAttemptsCount10
                case .noLimit: T.lockoutSettingsAppLockAttemptsNoLimit
                }
            }
        ))
    }
}
