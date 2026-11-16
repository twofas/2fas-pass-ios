// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common
import CommonUI

@MainActor @Observable
final class VaultRecoveryCameraPresenter {
    var freezeCamera = false
    var isCameraAvailable: Bool?
    var showInvalidCodeError = false

    private let interactor: VaultRecoveryCameraModuleInteracting
    private let onScanned: (Entropy, MasterKey?) -> Void
    private let scanDebouncer = ScanDebouncer()

    init(
        interactor: VaultRecoveryCameraModuleInteracting,
        onScanned: @escaping (Entropy, MasterKey?) -> Void
    ) {
        self.interactor = interactor
        self.onScanned = onScanned
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
                    self?.onScanned(result.entropy, result.masterKey)
                } else {
                    self?.freezeCamera = false
                    self?.showInvalidCodeError = true
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
