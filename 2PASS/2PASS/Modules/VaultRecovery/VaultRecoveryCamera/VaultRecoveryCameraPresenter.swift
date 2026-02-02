// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common
import CommonUI

enum VaultRecoveryCameraDestination: RouterDestination {
    case vaultRecovery(entropy: Entropy, masterKey: MasterKey, recoveryData: VaultRecoveryData, onTryAgain: Callback)
    case enterMasterPassword(flowContext: VaultRecoveryFlowContext, entropy: Entropy, recoveryData: VaultRecoveryData, onTryAgain: Callback)
    case importVault(BackupImportInput, onClose: Callback)

    var id: String {
        switch self {
        case .vaultRecovery: "vaultRecovery"
        case .enterMasterPassword: "enterMasterPassword"
        case .importVault: "importVault"
        }
    }
}

@MainActor @Observable
final class VaultRecoveryCameraPresenter {
    var freezeCamera = false
    var isCameraAvailable = false
    var showInvalidCodeError = false

    var destination: VaultRecoveryCameraDestination?

    private let interactor: VaultRecoveryCameraModuleInteracting
    private let flowContext: VaultRecoveryFlowContext
    private let recoveryData: VaultRecoveryData
    private let onTryAgain: Callback
    private let scanDebouncer = ScanDebouncer()

    init(
        interactor: VaultRecoveryCameraModuleInteracting,
        flowContext: VaultRecoveryFlowContext,
        recoveryData: VaultRecoveryData,
        onTryAgain: @escaping Callback
    ) {
        self.interactor = interactor
        self.flowContext = flowContext
        self.recoveryData = recoveryData
        self.onTryAgain = onTryAgain
    }

    func onAppear() {
        freezeCamera = false
        scanDebouncer.reset()

        interactor.checkCameraPermission { isCameraAvailable in
            self.isCameraAvailable = isCameraAvailable
        }
    }

    func onFoundCode(code: String) {
        guard !freezeCamera else { return }
        Log("VaultRecoveryCameraPresenter: Found code: \(code)")
        scheduleDetected(code: code)
    }

    func handleResumeCamera() {
        freezeCamera = false
    }

    func onCodeLost() {
        scheduleLost()
    }

    func onToAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}

private extension VaultRecoveryCameraPresenter {
    func scheduleDetected(code: String) {
        scanDebouncer.scheduleDetected(
            code: code,
            task: { [weak self] code in
                if let result = self?.interactor.parseQRCodeContents(code) {
                    self?.freezeCamera = true
                    self?.showInvalidCodeError = false
                    self?.navigateToNextScreen(entropy: result.entropy, masterKey: result.masterKey)
                } else {
                    self?.freezeCamera = false
                    self?.showInvalidCodeError = true
                }
            }
        )
    }

    func navigateToNextScreen(entropy: Entropy, masterKey: MasterKey?) {
        if let masterKey {
            switch flowContext.kind {
            case .onboarding, .restoreVault:
                destination = .vaultRecovery(
                    entropy: entropy,
                    masterKey: masterKey,
                    recoveryData: recoveryData,
                    onTryAgain: onTryAgain
                )
            case .importVault:
                switch recoveryData {
                case .cloud:
                    fatalError("Unsupported importing vault from cloud")
                case .localVault:
                    fatalError("Unsupported importing vault from local database")
                case .file(let vault):
                    destination = .importVault(.encrypted(entropy: entropy, masterKey: masterKey, vault: vault), onClose: flowContext.onClose)
                }
            }
        } else {
            destination = .enterMasterPassword(flowContext: flowContext, entropy: entropy, recoveryData: recoveryData, onTryAgain: onTryAgain)
        }
    }

    func scheduleLost() {
        scanDebouncer.scheduleLost { [weak self] in
            self?.freezeCamera = false
            self?.showInvalidCodeError = false
        }
    }
}
