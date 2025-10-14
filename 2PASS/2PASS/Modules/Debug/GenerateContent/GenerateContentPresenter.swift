// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

@Observable
final class GenerateContentPresenter {
    var isWorking = false
    var itemsCount: Int = 0
    var secureNotesCount = 0
    var unknownCount = 0

    private let interactor: GenerateContentModuleInteracting

    init(interactor: GenerateContentModuleInteracting) {
        self.interactor = interactor
    }
}

extension GenerateContentPresenter {
    func onAppear() {
        refreshCount()
    }
    
    func onRemoveAllItems() {
        isWorking = true
        interactor.removeAllItems()
        refreshCount()
        isWorking = false
    }
    
    func onGenerate(count: Int) {
        isWorking = true
        interactor.generateItems(count: count) { [weak self] in
            self?.refreshCount()
            self?.isWorking = false
        }
    }
    
    func onGenerateSecureNote(count: Int) {
        isWorking = true
        interactor.generateSecureNotes(count: count) { [weak self] in
            self?.refreshCount()
            self?.isWorking = false
        }
    }

    func onGenerateUnknown(count: Int) {
        isWorking = true
        interactor.generateUnknown(count: count) { [weak self] in
            self?.refreshCount()
            self?.isWorking = false
        }
    }

    private func refreshCount() {
        itemsCount = interactor.itemsCount
        secureNotesCount = interactor.secureNotesCount
        unknownCount = interactor.unknownCount
    }
}
