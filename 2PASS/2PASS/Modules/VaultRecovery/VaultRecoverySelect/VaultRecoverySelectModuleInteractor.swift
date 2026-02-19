// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

protocol VaultRecoverySelectModuleInteracting: AnyObject {
    func openFile(url: URL, completion: @escaping (Result<Data, ImportOpenFileError>) -> Void)
    func scan(image: UIImage, completion: @escaping VisionScanCompletion)
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
    func isPDF(fileURL: URL) -> Bool
    func pdfToImage(url: URL) -> UIImage?
    func validateEntropy(_ entropy: Entropy, for data: VaultRecoveryData) -> Bool
}

final class VaultRecoverySelectModuleInteractor {
    private let importInteractor: ImportInteracting
    private let recoveryKitScanInteractor: RecoveryKitScanInteracting
    
    init(
        importInteractor: ImportInteracting,
        recoveryKitScanInteractor: RecoveryKitScanInteracting
    ) {
        self.importInteractor = importInteractor
        self.recoveryKitScanInteractor = recoveryKitScanInteractor
    }
}

extension VaultRecoverySelectModuleInteractor: VaultRecoverySelectModuleInteracting {
    func openFile(url: URL, completion: @escaping (Result<Data, ImportOpenFileError>) -> Void) {
        importInteractor.openFile(url: url, completion: completion)
    }
    
    func scan(image: UIImage, completion: @escaping VisionScanCompletion) {
        recoveryKitScanInteractor.scan(image: image, completion: completion)
    }
    
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)? {
        recoveryKitScanInteractor.parseQRCodeContents(str)
    }
    
    func isPDF(fileURL: URL) -> Bool {
        recoveryKitScanInteractor.isPDF(fileURL: fileURL)
    }
    
    func pdfToImage(url: URL) -> UIImage? {
        recoveryKitScanInteractor.pdfToImage(url: url)
    }
    
    func validateEntropy(_ entropy: Entropy, for data: VaultRecoveryData) -> Bool {
        if case .localVault = data {
            return true
        }
        
        guard let vaultSeedHash = data.vaultSeedHash, let vaultID = data.vaultID else {
            return false
        }
        guard let seedHash = importInteractor.generateSeedHash(from: entropy, vaultID: vaultID) else {
            return false
        }
        
        let seedHashBase64 = Data(hexString: seedHash)?.base64EncodedString()
        return seedHashBase64 == vaultSeedHash
    }
}
