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
    
    init(cameraPermissionInteractor: CameraPermissionInteracting) {
        self.cameraPermissionInteractor = cameraPermissionInteractor
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
        guard let result = RecoveryKitLink.parse(from: str) else {
            return nil
        }
        let entropy = Data(base64Encoded: result.entropy)
        let masterKey = {
            if let masterKey = result.masterKey {
                return Data(base64Encoded: masterKey)
            }
            return nil
        }()
        guard let entropy else {
            return nil
        }
        return (entropy: entropy, masterKey: masterKey)
    }
}
