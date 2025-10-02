// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

struct EnterWordsWord: Hashable, Identifiable {
    let id: UUID
    let index: Int
    var word: String
    var isIncorrect: Bool
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(index)
        hasher.combine(word)
        hasher.combine(isIncorrect)
    }
    
    static func createList(count: Int) -> [EnterWordsWord] {
        (0..<count).map { index in
            empty(index: index)
        }
    }
    
    static func empty(index: Int) -> EnterWordsWord {
        .init(id: UUID(), index: index, word: "", isIncorrect: false)
    }
}

enum VaultRecoveryEnterWordsDestination: Identifiable {
    var id: String {
        switch self {
        case .incorrectWordsAlert: "incorrectWordsAler"
        }
    }
    case incorrectWordsAlert
}

@Observable
final class VaultRecoveryEnterWordsPresenter {

    private(set) var canSaveWordsManually = false
    
    var destination: VaultRecoveryEnterWordsDestination?
    
    var words: [EnterWordsWord] = EnterWordsWord.createList(count: Config.wordsCount) {
        didSet {
            updateWordsSaveState()
        }
    }
    
    private let interactor: VaultRecoveryEnterWordsModuleInteracting
    private let recoveryData: VaultRecoveryData
    private let onEntropy: (Entropy) -> Void
    
    init(
        interactor: VaultRecoveryEnterWordsModuleInteracting,
        recoveryData: VaultRecoveryData,
        onEntropy: @escaping (Entropy) -> Void
    ) {
        self.interactor = interactor
        self.recoveryData = recoveryData
        self.onEntropy = onEntropy
    }
    
    func onWordsSave() {
        let words = self.words.map { $0.word }
        if interactor.validateWords(words, using: recoveryData),
           let entropy = interactor.wordsToEntropy(words) {
            onEntropy(entropy)
        } else {
            destination = .incorrectWordsAlert
        }
    }
}

private extension VaultRecoveryEnterWordsPresenter {
    func updateWordsSaveState() {
        var currentWords = words
        var correctWords = 0
        for (index, wordStorage) in currentWords.enumerated() {
            let word = wordStorage.word.trim()
            if !word.isEmpty {
                var savedWord = currentWords[index]
                if let newWord = interactor.parseWord(word) {
                    savedWord.word = newWord
                    savedWord.isIncorrect = false
                    correctWords += 1
                } else {
                    savedWord.isIncorrect = true
                }
                currentWords[index] = savedWord
            } else {
                var savedWord = currentWords[index]
                savedWord.isIncorrect = false
                currentWords[index] = savedWord
            }
        }
        
        if currentWords != words {
            words = currentWords
        }
        canSaveWordsManually = correctWords == Config.wordsCount
    }
}
