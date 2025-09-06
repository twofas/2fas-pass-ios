// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data
import SwiftUI
import CommonUI

enum MasterPasswordDestination: RouterDestination {

    var id: String {
        switch self {
        case .restoreVault: "restoreVault"
        case .vaultDecryptionKit: "vaultDecryptionKit"
        case .onboardingRecoveryKit: "onboardingRecoveryKit"
        case .confirmChange: "confirmChange"
        case .changeSuccess: "changeSuccess"
        }
    }
    
    case restoreVault(passwords: [ItemData], tags: [ItemTagData])
    case vaultDecryptionKit(onLogin: Callback)
    case onboardingRecoveryKit
    case confirmChange(onConfirm: Callback)
    case changeSuccess(onFinish: Callback)
}

private struct Constants {
    static let saveDelayForHideKeyboard: Duration = .milliseconds(500)
    static let pushDelayAfterConfirm: Duration = .milliseconds(600) // Starting a push after a modal dismiss sets the destination to nil.
}

@Observable
final class MasterPasswordPresenter {
    
    enum State {
        case empty
        case tooShort
        case dontMatch
        case ok
    }
    
    var firstInput = "" {
        didSet {
            guard oldValue != secondInput else { return }
            updateState()
            showError = false
        }
    }
    var secondInput = "" {
        didSet {
            guard oldValue != secondInput else { return }
            updateState()
            showError = false
        }
    }
    
    var firstInputReveal = false
    var secondInputReveal = false

    private(set) var showError = false
    private(set) var isSaveEnabled = false
    private(set) var currentState: State = .empty
    private(set) var isRetype: Bool = false
    let optimalLength = Config.minMasterPasswordLength
    
    private let interactor: MasterPasswordModuleInteracting
    let kind: MasterPasswordKind
    private let onFinish: Callback
    let onClose: Callback
    
    var destination: MasterPasswordDestination?
    
    init(
        interactor: MasterPasswordModuleInteracting,
        kind: MasterPasswordKind,
        onFinish: @escaping Callback,
        onClose: @escaping Callback
    ) {
        self.interactor = interactor
        self.kind = kind
        self.onFinish = onFinish
        self.onClose = onClose
    }
}

extension MasterPasswordPresenter {
    
    func onSavePassword() {
        if isRetype == false {
            withAnimation {
                isRetype = true
            }
            return
        }
        
        guard currentState == .ok else {
            showError = true
            return
        }
        
        switch kind {
        case .change:
            destination = .confirmChange(onConfirm: { [weak self] in
                self?.destination = nil
                
                Task { @MainActor in
                    try await Task.sleep(for: Constants.pushDelayAfterConfirm)
                    self?.performChangePassword()
                }
            })
        case .onboarding, .unencryptedVaultRecovery:
            Task { @MainActor in
                try await Task.sleep(for: Constants.saveDelayForHideKeyboard)
                performChangePassword()
            }
        }
    }
    
    private func performChangePassword() {
        interactor.createMasterPassword(firstInput, enableBiometryLogin: false) { [weak self] in
            guard let self else { return }
            switch kind {
            case .onboarding:
                destination = .onboardingRecoveryKit
            case .change:
                destination = .changeSuccess(onFinish: onFinish)
            case .unencryptedVaultRecovery(let passwords, let tags):
                destination = .restoreVault(
                    passwords: passwords,
                    tags: tags
                )
            }
        }
    }
}

private extension MasterPasswordPresenter {
    
    func updateState() {
        isSaveEnabled = false
        
        if isRetype {
            if secondInput.isEmpty, firstInput.count >= optimalLength {
                currentState = .empty
                return
            }
            
            if firstInput.count < optimalLength || secondInput.count < optimalLength {
                currentState = .tooShort
            } else {
                if firstInput == secondInput  {
                    currentState = .ok
                } else {
                    currentState = .dontMatch
                }
                
                isSaveEnabled = true
            }
            
        } else {
            if firstInput.isEmpty {
                currentState = .empty
                return
            }
            
            if firstInput.count < optimalLength {
                currentState = .tooShort
            } else {
                currentState = .ok
                isSaveEnabled = true
            }
        }
    }
}
