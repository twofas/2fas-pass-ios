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

@Observable
final class ForgotMasterPasswordDecryptionKitCameraPresenter {
    var freezeCamera = false
    var isCameraAvailable = false
    var showInvalidCodeError = false
    
    private var pendingTask: Task<Void, Never>?
    private var pendingCode: String?
    
    var destination: ForgotMasterPasswordDecryptionKitCameraDestination?
    
    private let interactor: ForgotMasterPasswordDecryptionKitCameraModuleInteracting
    private let config: LoginModuleInteractorConfig
    private let onSuccess: Callback
    private let onTryAgain: Callback
    private let onClose: Callback

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
        pendingCode = nil
        
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
        guard pendingCode != code else { return }
        pendingCode = code
        cancelPendingTask()
        pendingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, self.pendingCode == code else { return }
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
    }
    
    func scheduleLost() {
        guard pendingCode != nil else { return }
        pendingCode = nil
        cancelPendingTask()
        pendingTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, self.pendingCode == nil else { return }
            self.freezeCamera = false
            self.showInvalidCodeError = false
        }
    }
    
    func cancelPendingTask() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
