// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol VaultRecoveryCameraModuleInteracting: AnyObject {
    func checkCameraPermission(completion: @escaping (Bool) -> Void)
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
    func validateEntropy(_ entropy: Entropy, for data: VaultRecoveryData) -> Bool
}

final class VaultRecoveryCameraModuleInteractor {
    private let cameraPermissionInteractor: CameraPermissionInteracting
    private let recoveryKitScanner: RecoveryKitScanCameraInteracting
    private let importInteractor: ImportInteracting

    init(
        cameraPermissionInteractor: CameraPermissionInteracting,
        recoveryKitScanner: RecoveryKitScanCameraInteracting,
        importInteractor: ImportInteracting
    ) {
        self.cameraPermissionInteractor = cameraPermissionInteractor
        self.recoveryKitScanner = recoveryKitScanner
        self.importInteractor = importInteractor
    }
}

extension VaultRecoveryCameraModuleInteractor: VaultRecoveryCameraModuleInteracting {
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

    func validateEntropy(_ entropy: Entropy, for data: VaultRecoveryData) -> Bool {
        if case .localVault = data {
            return true
        }

        guard let vaultSeedHash = data.vaultSeedHash, let vaultID = data.vaultID else {
            return false
        }
        return importInteractor.validateEntropy(entropy, using: vaultSeedHash, vaultID: vaultID)
    }
}
