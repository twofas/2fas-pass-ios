// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

typealias VaultRecoveryCameraCompletion = (_ entropy: Entropy, _ masterKey: MasterKey?) -> Void

enum VaultRecoveryCameraDestination: Identifiable {
    var id: String {
        switch self {
        case .cameraQRCodeError: "cameraQRCodeError"
        }
    }
    
    case cameraQRCodeError(onFinish: Callback)
}

@Observable
final class VaultRecoveryCameraPresenter {
    var freezeCamera = false
    var isCameraAvailable = false
    
    var destination: VaultRecoveryCameraDestination?
    
    private let interactor: VaultRecoveryCameraModuleInteracting
    private let onCompletion: VaultRecoveryCameraCompletion
    
    init(
        interactor: VaultRecoveryCameraModuleInteracting,
        onCompletion: @escaping VaultRecoveryCameraCompletion
    ) {
        self.interactor = interactor
        self.onCompletion = onCompletion
    }
    
    func onAppear() {
        interactor.checkCameraPermission { isCameraAvailable in
            self.isCameraAvailable = isCameraAvailable
        }
    }
    
    func onFoundCode(code: String) {
        guard !freezeCamera else { return }
        freezeCamera = true
        Log("EnterWordsPresenter: Found code: \(code)")
        if let result = interactor.parseQRCodeContents(code) {
            onCompletion(result.entropy, result.masterKey)
        } else {
            destination = .cameraQRCodeError { [weak self] in
                self?.destination = nil
            }
        }
    }
    
    func handleResumeCamera() {
        freezeCamera = false
    }
    
    func onToAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
}
