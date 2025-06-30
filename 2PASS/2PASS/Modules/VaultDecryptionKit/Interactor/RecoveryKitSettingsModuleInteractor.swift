// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

final class RecoveryKitSettingsModuleInteractor {
    private let protectionInteractor: ProtectionInteracting
    private let recoveryKitInteractor: RecoveryKitInteracting
    
    init(protectionInteractor: ProtectionInteracting, recoveryKitInteractor: RecoveryKitInteracting) {
        self.protectionInteractor = protectionInteractor
        self.recoveryKitInteractor = recoveryKitInteractor
    }
}

extension RecoveryKitSettingsModuleInteractor: RecoveryKitModuleInteracting {

    func generateRecoveryKitPDF(includeMasterKey: Bool, completion: @escaping (URL?) -> Void) {
        guard let words = protectionInteractor.words,
              let entropy = protectionInteractor.entropy,
              let masterKey = protectionInteractor.masterKey
        else {
            Log(
                "RecoveryKitSettingsInteractor: Error - no elements for generating Recovery Kit PDF",
                module: .moduleInteractor
            )
            return
        }
        
        recoveryKitInteractor.generateRecoveryKitPDF(
            entropy: entropy,
            words: words,
            masterKey: includeMasterKey ? masterKey : nil,
            completion: completion
        )
    }
    
    func clear() {
        recoveryKitInteractor.clear()
    }
}
