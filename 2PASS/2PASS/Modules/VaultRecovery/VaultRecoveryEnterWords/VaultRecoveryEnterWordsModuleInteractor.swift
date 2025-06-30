// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol VaultRecoveryEnterWordsModuleInteracting: AnyObject {
    func wordsToEntropy(_ words: [String]) -> Entropy?
    func parseWord(_ word: String) -> String?
    func validateWords(_ words: [String], using recoveryData: VaultRecoveryData) -> Bool
}

final class VaultRecoveryEnterWordsModuleInteractor {
    private let startupInteractor: StartupInteracting
    private let importInteractor: ImportInteracting
    
    private var allWords: [String]
    
    init(startupInteractor: StartupInteracting, importInteractor: ImportInteracting) {
        self.startupInteractor = startupInteractor
        self.importInteractor = importInteractor
        
        allWords = startupInteractor.getAllWords()
    }
}

extension VaultRecoveryEnterWordsModuleInteractor: VaultRecoveryEnterWordsModuleInteracting {
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
    
    func validateWords(_ words: [String], using recoveryData: VaultRecoveryData) -> Bool {
        switch recoveryData {
        case .file(let exchangeVault):
            guard let externalSeedHash = exchangeVault.encryption?.seedHash,
                  let vaultID = UUID(uuidString: exchangeVault.vault.id) else {
                Log(
                    "VaultRecoveryEnterWordsModuleInteractor: Can't get VaultID or seedHash for validation",
                    module: .moduleInteractor
                )
                return false
            }
            return importInteractor.validateWords(words, using: externalSeedHash, vaultID: vaultID)
        case .cloud(let vaultRawData):
            return importInteractor.validateWords(words, using: vaultRawData.seedHash, vaultID: vaultRawData.vaultID)
        }
    }
}
