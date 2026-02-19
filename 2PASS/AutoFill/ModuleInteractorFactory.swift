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
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            securityInteractor: InteractorFactory.shared.securityInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            loginItemInteractor: InteractorFactory.shared.loginItemInteractor(),
            autoFillCredentialsInteractor: InteractorFactory.shared.autoFillCredentialsInteractor(),
            passwordGeneratorInteractor: InteractorFactory.shared.passwordGeneratorInteractor(),
            pushNotificationsInteractor: InteractorFactory.shared.pushNotificationsInteractor()
        )
    }
}
