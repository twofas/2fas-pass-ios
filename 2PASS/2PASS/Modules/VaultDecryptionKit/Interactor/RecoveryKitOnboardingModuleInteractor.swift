// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

final class RecoveryKitOnboardingModuleInteractor {
    private let startupInteractor: StartupInteracting
    private let recoveryKitInteractor: RecoveryKitInteracting
    
    init(startupInteractor: StartupInteracting, recoveryKitInteractor: RecoveryKitInteracting) {
        self.startupInteractor = startupInteractor
        self.recoveryKitInteractor = recoveryKitInteractor
    }
}

extension RecoveryKitOnboardingModuleInteractor: RecoveryKitModuleInteracting {
        
    func generateRecoveryKitPDF(includeMasterKey: Bool, completion: @escaping (URL?) -> Void) {
        guard let entropy = startupInteractor.entropy,
              let words = startupInteractor.words
            else {
            Log(
                "RecoveryKitInteractor: Error - no encryption elements for generating Recovery Kit PDF",
                module: .moduleInteractor
            )
            return
        }

        let masterKey = startupInteractor.masterKey

        recoveryKitInteractor.generateRecoveryKitPDF(
            entropy: entropy,
            words: words,
            masterKey: includeMasterKey ? masterKey : nil,
            completion: completion
        )
    }
    
    func clear() {
        recoveryKitInteractor.clear()
        startupInteractor.clearAfterInit()
    }
}
