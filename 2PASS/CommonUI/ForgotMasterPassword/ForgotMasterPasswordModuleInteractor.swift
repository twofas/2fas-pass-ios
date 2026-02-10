// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

protocol ForgotMasterPasswordModuleInteracting: AnyObject {
    var loginConfig: LoginModuleInteractorConfig { get }
    
    func openFile(url: URL, completion: @escaping (Result<Data, ImportOpenFileError>) -> Void)
    func scan(image: UIImage, completion: @escaping VisionScanCompletion)
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
    func isPDF(fileURL: URL) -> Bool
    func pdfToImage(url: URL) -> UIImage?
    func validateEntropy(_ entropy: Entropy) -> Bool
    func verifyMasterKey(_ masterKey: MasterKey) -> Bool
    func loginUsingMasterKey(_ masterKey: MasterKey, entropy: Entropy) async -> Bool
}

final class ForgotMasterPasswordModuleInteractor {
    let loginConfig: LoginModuleInteractorConfig
    
    private let importInteractor: ImportInteracting
    private let recoveryKitScanInteractor: RecoveryKitScanInteracting
    private let protectionInteractor: ProtectionInteracting
    private let loginInteractor: LoginInteracting
    
    init(
        importInteractor: ImportInteracting,
        recoveryKitScanInteractor: RecoveryKitScanInteracting,
        protectionInteractor: ProtectionInteracting,
        loginInteractor: LoginInteracting,
        loginConfig: LoginModuleInteractorConfig
    ) {
        self.importInteractor = importInteractor
        self.recoveryKitScanInteractor = recoveryKitScanInteractor
        self.protectionInteractor = protectionInteractor
        self.loginInteractor = loginInteractor
        self.loginConfig = loginConfig
    }
}

extension ForgotMasterPasswordModuleInteractor: ForgotMasterPasswordModuleInteracting {
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

    func validateEntropy(_ entropy: Entropy) -> Bool {
        protectionInteractor.validateEntropyMatchesCurrentVault(entropy)
    }

    func verifyMasterKey(_ masterKey: MasterKey) -> Bool {
        protectionInteractor.verifyMasterKey(masterKey)
    }

    @MainActor
    func loginUsingMasterKey(_ masterKey: MasterKey, entropy: Entropy) async -> Bool {
        switch loginConfig.loginType {
        case .login:
            return await loginInteractor.loginUsingMasterKey(masterKey, entropy: entropy)
        case .verify:
            return loginInteractor.verifyMasterKey(masterKey, entropy: entropy)
        case .restore:
            return false
        }
        
    }
}
