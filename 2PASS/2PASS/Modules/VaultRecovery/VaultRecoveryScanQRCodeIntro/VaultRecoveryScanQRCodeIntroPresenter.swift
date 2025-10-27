// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI
import Data

enum VaultRecoveryScanQRCodeIntroDestination: RouterDestination {
    case camera(VaultRecoveryData, onCompletion: VaultRecoveryCameraCompletion)
    
    case vaultRecovery(
        entropy: Entropy,
        masterKey: MasterKey,
        recoveryData: VaultRecoveryData
    )
    
    case enterMasterPassword(
        flowContext: VaultRecoveryFlowContext,
        entropy: Entropy,
        recoveryData: VaultRecoveryData
    )
    
    case importVault(BackupImportInput, onClose: Callback)
    
    var id: String {
        switch self {
        case .camera: "camera"
        case .enterMasterPassword: "enterMasterPassword"
        case .vaultRecovery: "vaultRecovery"
        case .importVault: "importing"
        }
    }
}

@Observable
final class VaultRecoveryScanQRCodeIntroPresenter {
    
    var destination: VaultRecoveryScanQRCodeIntroDestination?
    
    private let flowContext: VaultRecoveryFlowContext
    private let recoveryData: VaultRecoveryData
    
    init(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData) {
        self.flowContext = flowContext
        self.recoveryData = recoveryData
    }
    
    func onContinue() {
        destination = .camera(recoveryData, onCompletion: { [weak self] entropy, masterKey in
            self?.destination = nil
            
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(700))
                
                guard let self else { return }
                
                if let masterKey {
                    switch self.flowContext.kind {
                    case .onboarding, .restoreVault:
                        self.destination = .vaultRecovery(
                            entropy: entropy,
                            masterKey: masterKey,
                            recoveryData: self.recoveryData
                        )
                    case .importVault:
                        switch self.recoveryData {
                        case .cloud:
                            fatalError("Unsupported importing vault from cloud")
                        case .localVault:
                            fatalError("Unsupported importing vault from local database")
                        case .file(let vault):
                            self.destination = .importVault(.encrypted(entropy: entropy, masterKey: masterKey, vault: vault), onClose: self.flowContext.onClose)
                        }
                    }
                    
                } else {
                    self.destination = .enterMasterPassword(
                        flowContext: self.flowContext,
                        entropy: entropy,
                        recoveryData: self.recoveryData
                    )
                }
            }   
        })
    }
}
