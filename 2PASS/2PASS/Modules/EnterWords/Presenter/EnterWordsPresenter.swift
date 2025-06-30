// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

@Observable
final class EnterWordsPresenter {
    var freezeCamera = false
    var isCameraAvailable = false
    var canSaveWordsManually = false
    var showScanQRCode = false
    var showEnterWords = false
    var showQRCodeError = false
    var showIncorrectWordsError = false
    var showGeneralError = false
    
    var words: [EnterWordsWord] = EnterWordsWord.createList(count: Config.wordsCount) {
        didSet {
            updateWordsSaveState()
        }
    }
    
    private let flowController: EnterWordsFlowControlling
    private let interactor: EnterWordsModuleInteracting
    private let fileData: ExchangeVault?
    
    init(flowController: EnterWordsFlowControlling, interactor: EnterWordsModuleInteracting, fileData: ExchangeVault?) {
        self.flowController = flowController
        self.interactor = interactor
        self.fileData = fileData
        
        interactor.checkCameraPermission { isCameraAvailable in
            self.isCameraAvailable = isCameraAvailable
        }
    }
    
    func onCancelScanQRCode() {
        showEnterWords = false
    }
    
    func onCancelEnterWords() {
        showEnterWords = false
    }
    
    func onFoundCode(code: String) {
        guard !freezeCamera else { return }
        freezeCamera = true
        showScanQRCode = false
        Log("EnterWordsPresenter: Found code: \(code)")
        if let result = interactor.parseQRCodeContents(code) {
            if let fileData {
                if let masterKey = result.masterKey {
                    flowController.toDecrypt(
                        with: masterKey,
                        entropy: result.entropy,
                        fileData: fileData
                    )
                } else {
                    flowController.toEnterMasterPassword(entropy: result.entropy, fileData: fileData)
                }
            } else {
                if let masterKey = result.masterKey {
                    if interactor.setEntropy(entropy: result.entropy, masterKey: masterKey) {
                        flowController.close()
                    } else {
                        showQRCodeError = true
                    }
                } else {
                    interactor.setEntropy(entropy: result.entropy, masterKey: nil)
                    flowController.toEnterMasterPassword()
                }
            }
        } else {
            showQRCodeError = true
        }
    }
    
    func onWordsSave() {
        let words = self.words.map { $0.word }
        if let fileData {
            if interactor.validateWords(words, using: fileData),
               let entropy = interactor.wordsToEntropy(words) {
                showEnterWords = false
                flowController.toEnterMasterPassword(entropy: entropy, fileData: fileData)
            } else {
                showEnterWords = false
                showIncorrectWordsError = true
            }
        } else {
            switch interactor.setWords(words: words, masterPassword: nil) {
            case .success: flowController.close()
            case .wrongWords: showIncorrectWordsError = true
            case .generalError: showGeneralError = true
            }
        }
    }
    
    func handleResumeCamera() {
        freezeCamera = false
    }
    
    func onToAppSettings() {
        flowController.toAppSettings()
    }
}

private extension EnterWordsPresenter {
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
            }
        }
        
        if currentWords != words {
            words = currentWords
        }
        canSaveWordsManually = correctWords == Config.wordsCount
    }
}

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
