// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Data

extension ModuleInteractorFactory {
    
    func autoFillInteractor() -> AutoFillModuleInteracting {
        AutoFillModuleInteractor(
            passwordInteractor: InteractorFactory.shared.passwordInteractor(),
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            securityInteractor: InteractorFactory.shared.securityInteractor()
        )
    }
}
