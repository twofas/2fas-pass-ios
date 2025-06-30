// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol VaultRecoveryModuleInteracting: AnyObject {
    func setupEncryptionElements()
}

final class VaultRecoveryModuleInteractor {
    private let startupInteractor: StartupInteracting
    
    init(startupInteractor: StartupInteracting) {
        self.startupInteractor = startupInteractor
    }
}

extension VaultRecoveryModuleInteractor: VaultRecoveryModuleInteracting {
    func setupEncryptionElements() {
        startupInteractor.setupEncryptionElements()
    }
}
