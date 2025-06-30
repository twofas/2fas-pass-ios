// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

@Observable
final class GenerateContentPresenter {
    var isWorking = false
    var passwordCount: Int = 0
    
    private let interactor: GenerateContentModuleInteracting
    
    init(interactor: GenerateContentModuleInteracting) {
        self.interactor = interactor
    }
}

extension GenerateContentPresenter {
    func onAppear() {
        refreshCount()
    }
    
    func onRemoveAllPasswords() {
        isWorking = true
        interactor.removeAllPasswords()
        refreshCount()
        isWorking = false
    }
    
    func onGenerate(count: Int) {
        isWorking = true
        interactor.generatePasswords(count: count) { [weak self] in
            self?.refreshCount()
            self?.isWorking = false
        }
    }
    
    private func refreshCount() {
        passwordCount = interactor.passwordCount
    }
}
