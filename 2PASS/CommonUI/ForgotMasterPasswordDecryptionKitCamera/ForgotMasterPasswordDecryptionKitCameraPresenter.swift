// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

public enum ForgotMasterPasswordDecryptionKitCameraDestination: RouterDestination {
    public var id: String {
        switch self {
        case .recovery: "recovery"
        }
    }
    
    case recovery(
        entropy: Entropy,
        masterKey: MasterKey?,
        config: LoginModuleInteractorConfig,
        onSuccess: Callback,
        onTryAgain: Callback,
        onClose: Callback
    )
}

@MainActor @Observable
final class ForgotMasterPasswordDecryptionKitCameraPresenter {
    var freezeCamera = false
    var isCameraAvailable = false
    var showInvalidCodeError = false

    var destination: ForgotMasterPasswordDecryptionKitCameraDestination?

    private let interactor: ForgotMasterPasswordDecryptionKitCameraModuleInteracting
    private let config: LoginModuleInteractorConfig
    private let onSuccess: Callback
    private let onTryAgain: Callback
    private let onClose: Callback
    private let scanDebouncer = ScanDebouncer()

    init(
        interactor: ForgotMasterPasswordDecryptionKitCameraModuleInteracting,
        config: LoginModuleInteractorConfig,
        onSuccess: @escaping Callback,
        onTryAgain: @escaping Callback,
        onClose: @escaping Callback
    ) {
        self.interactor = interactor
        self.config = config
        self.onSuccess = onSuccess
        self.onTryAgain = onTryAgain
        self.onClose = onClose
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
        Log("ForgotMasterPasswordDecryptionKitCameraPresenter: Found code: \(code)")
        scheduleDetected(code: code)
    }

    func onCodeLost() {
        scheduleLost()
    }

    func onAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}

private extension ForgotMasterPasswordDecryptionKitCameraPresenter {
    func scheduleDetected(code: String) {
        scanDebouncer.scheduleDetected(
            code: code,
            task: { [weak self] code in
                guard let self else { return }
                
                if let result = self.interactor.parseQRCodeContents(code) {
                    self.freezeCamera = true
                    self.showInvalidCodeError = false
                    self.destination = .recovery(
                        entropy: result.entropy,
                        masterKey: result.masterKey,
                        config: self.config,
                        onSuccess: self.onSuccess,
                        onTryAgain: self.onTryAgain,
                        onClose: self.onClose
                    )
                } else {
                    self.freezeCamera = false
                    self.showInvalidCodeError = true
                }
            }
        )
    }

    func scheduleLost() {
        scanDebouncer.scheduleLost { [weak self] in
            self?.freezeCamera = false
            self?.showInvalidCodeError = false
        }
    }
}
