// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol ShareLinkItemPasswordModuleInteracting: AnyObject {
    func generatePassword() -> String
}

final class ShareLinkItemPasswordModuleInteractor: ShareLinkItemPasswordModuleInteracting {
    private let passwordGeneratorInteractor: PasswordGeneratorInteracting
    private let configInteractor: ConfigInteracting

    init(
        passwordGeneratorInteractor: PasswordGeneratorInteracting,
        configInteractor: ConfigInteracting
    ) {
        self.passwordGeneratorInteractor = passwordGeneratorInteractor
        self.configInteractor = configInteractor
    }

    func generatePassword() -> String {
        let config = configInteractor.passwordGeneratorConfig ?? .init(
            length: passwordGeneratorInteractor.prefersPasswordLength,
            hasDigits: true,
            hasUppercase: true,
            hasSpecial: true
        )
        return passwordGeneratorInteractor.generatePassword(using: config)
    }
}
