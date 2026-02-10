// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol ForgotMasterPasswordDecryptionKitCameraModuleInteracting: AnyObject {
    func checkCameraPermission(completion: @escaping (Bool) -> Void)
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
}

final class ForgotMasterPasswordDecryptionKitCameraModuleInteractor {
    private let cameraPermissionInteractor: CameraPermissionInteracting
    private let recoveryKitScanner: RecoveryKitScanCameraInteracting

    init(
        cameraPermissionInteractor: CameraPermissionInteracting,
        recoveryKitScanner: RecoveryKitScanCameraInteracting
    ) {
        self.cameraPermissionInteractor = cameraPermissionInteractor
        self.recoveryKitScanner = recoveryKitScanner
    }
}

extension ForgotMasterPasswordDecryptionKitCameraModuleInteractor: ForgotMasterPasswordDecryptionKitCameraModuleInteracting {
    func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        if cameraPermissionInteractor.isCameraAvailable == false {
            completion(false)
            return
        }
        cameraPermissionInteractor.checkPermission { value in
            completion(value)
        }
    }

    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)? {
        recoveryKitScanner.parseQRCodeContents(str)
    }
}
