// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol BiometricPromptModuleInteracting: AnyObject {
    var biometryType: BiometryType { get }
    func enableBiometric() async -> Bool
    func finish()
}

final class BiometricPromptModuleInteractor: BiometricPromptModuleInteracting {
    
    private let biometryInteractor: BiometryInteracting
    private let loginInteractor: LoginInteracting
    
    init(biometryInteractor: BiometryInteracting, loginInteractor: LoginInteracting) {
        self.biometryInteractor = biometryInteractor
        self.loginInteractor = loginInteractor
    }
    
    var biometryType: BiometryType {
        biometryInteractor.biometryType
    }
    
    func enableBiometric() async -> Bool {
        await withCheckedContinuation { continuation in
            biometryInteractor.setBiometryEnabled(true) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    func finish() {
        loginInteractor.clearMasterKey()
        loginInteractor.finishRequestForBiometryToLogin()
    }
}
