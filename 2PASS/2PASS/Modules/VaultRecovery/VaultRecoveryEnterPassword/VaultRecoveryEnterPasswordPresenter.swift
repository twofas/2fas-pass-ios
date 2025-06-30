// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

enum VaultRecoveryEnterPasswordDestination: Identifiable {
    var id: String {
        switch self {
        case .recover: "recover"
        case .masterPasswordError: "masterPasswordError"
        case .importVault: "importVault"
        }
    }
    case recover(
        entropy: Entropy,
        masterKey: MasterKey,
        recoveryData: VaultRecoveryData
    )
    
    case importVault(
        entropy: Entropy,
        masterKey: MasterKey,
        vault: ExchangeVault,
        onClose: Callback
    )
    
    case masterPasswordError(message: String)
}

@Observable
final class VaultRecoveryEnterPasswordPresenter {
    private let flowContext: VaultRecoveryFlowContext
    private let interactor: VaultRecoveryEnterPasswordModuleInteracting
    
    var password: String = "" {
        didSet {
            refreshStatus()
        }
    }
    var isPasswordAvailable = false
    var destination: VaultRecoveryEnterPasswordDestination?
        
    init(
        flowContext: VaultRecoveryFlowContext,
        interactor: VaultRecoveryEnterPasswordModuleInteracting
    ) {
        self.flowContext = flowContext
        self.interactor = interactor
    }
}

extension VaultRecoveryEnterPasswordPresenter {
    func onAppear() {
        refreshStatus()
    }
    
    func onDecrypt() {
        guard hasInput else {
            return
        }
        interactor.masterPasswordToMasterKey(password) { [weak self] masterKey in
            guard let self, let masterKey else {
                self?.destination = .masterPasswordError(message: T.lockScreenUnlockInvalidPassword)
                return
            }
            
            switch flowContext.kind {
            case .onboarding:
                destination = .recover(
                    entropy: interactor.entropy,
                    masterKey: masterKey,
                    recoveryData: interactor.recoveryData
                )
            case .importVault:
                switch interactor.recoveryData {
                case .file(let vault):
                    destination = .importVault(entropy: interactor.entropy, masterKey: masterKey, vault: vault, onClose: flowContext.onClose ?? {})
                case .cloud:
                    fatalError("Unsupported import vault from cloud")
                }
            }
        }
    }
}

private extension VaultRecoveryEnterPasswordPresenter {
    var hasInput: Bool {
        password.count >= Config.minMasterPasswordLength
    }
    
    func refreshStatus() {
        isPasswordAvailable = hasInput
    }
}
