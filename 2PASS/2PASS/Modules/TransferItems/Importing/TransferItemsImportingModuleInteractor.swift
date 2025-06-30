// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol TransferItemsImportingModuleInteracting {
    func importPasswords() async
}

final class TransferItemsImportingModuleInteractor: TransferItemsImportingModuleInteracting {
    
    private let passwordImportInteractor: PasswordImportInteracting
    
    let service: ExternalService
    let passwords: [PasswordData]
    
    init(service: ExternalService, passwords: [PasswordData], passwordImportInteractor: PasswordImportInteracting) {
        self.service = service
        self.passwords = passwords
        self.passwordImportInteractor = passwordImportInteractor
    }
    
    @MainActor
    func importPasswords() async {
        await withCheckedContinuation { continuation in
            passwordImportInteractor.importPasswords(passwords, tags: []) { _ in
                continuation.resume()
            }
        }
    }
}
