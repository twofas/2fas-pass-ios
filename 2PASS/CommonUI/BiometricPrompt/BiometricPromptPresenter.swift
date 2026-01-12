// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

@Observable
final class BiometricPromptPresenter {
 
    var biometryType: BiometryType {
        interactor.biometryType
    }
    
    private(set) var isEnabling = false
    
    private let interactor: BiometricPromptModuleInteracting
    private let onClose: Callback
    
    init(interactor: BiometricPromptModuleInteracting, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onClose = onClose
    }
    
    @MainActor
    func onEnable() {
        isEnabling = true
        
        Task {
            _ = await interactor.enableBiometric()
            interactor.finish()
            onClose()
            
            isEnabling = false
        }
    }
    
    func onCancel() {
        interactor.finish()
        onClose()
    }
}
