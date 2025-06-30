// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

enum EnterWordsResult {
    case success
    case wrongWords
    case generalError
}

protocol EnterWordsModuleInteracting: AnyObject {
    func checkCameraPermission(completion: @escaping (Bool) -> Void)
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
    func wordsToEntropy(_ words: [String]) -> Entropy?
    func parseWord(_ word: String) -> String?
    @discardableResult
    func setEntropy(entropy: Entropy, masterKey: MasterKey?) -> Bool
    func setWords(words: [String], masterPassword: MasterPassword?) -> EnterWordsResult
    func validateWords(_ words: [String], using fileData: ExchangeVault) -> Bool
}

final class EnterWordsModuleInteractor {
    private let cameraPermissionInteractor: CameraPermissionInteracting
    private let startupInteractor: StartupInteracting
    private let importInteractor: ImportInteracting
    
    private var allWords: [String]
    
    init(cameraPermissionInteractor: CameraPermissionInteracting, startupInteractor: StartupInteracting, importInteractor: ImportInteracting) {
        self.cameraPermissionInteractor = cameraPermissionInteractor
        self.startupInteractor = startupInteractor
        self.importInteractor = importInteractor
        
        allWords = startupInteractor.getAllWords()
    }
}

extension EnterWordsModuleInteractor: EnterWordsModuleInteracting {
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
    
    func wordsToEntropy(_ words: [String]) -> Entropy? {
        startupInteractor.wordsToEntropy(words)
    }
    
    func parseWord(_ word: String) -> String? {
        let word = word.lowercased()
        if allWords.contains(where: { $0 == word }) {
            return word
        }
        return nil
    }
    
    @discardableResult
    func setEntropy(entropy: Entropy, masterKey: MasterKey?) -> Bool {
        startupInteractor.setEntropy(entropy, masterKey: masterKey)
    }
    
    func setWords(words: [String], masterPassword: MasterPassword?) -> EnterWordsResult {
        switch startupInteractor.setWords(words: words, masterPassword: masterPassword) {
        case .success: .success
        case .wrongWords: .wrongWords
        case .generalError: .generalError
        }
    }
    
    func validateWords(_ words: [String], using fileData: ExchangeVault) -> Bool {
        let id = fileData.vault.id
        guard let vaultID = VaultID(uuidString: id), let seedHash = fileData.encryption?.seedHash else {
            return false
        }
        return importInteractor.validateWords(words, using: seedHash, vaultID: vaultID)
    }
}
