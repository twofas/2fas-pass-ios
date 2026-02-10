// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol ForgotMasterPasswordRecoveryModuleInteracting: AnyObject {
    var isAppLocked: Bool { get }
    func validateEntropy(_ entropy: Entropy) -> Bool
    func loginUsingMasterKey(_ masterKey: MasterKey, entropy: Entropy) async -> Bool
}

final class ForgotMasterPasswordRecoveryModuleInteractor {
    private let loginConfig: LoginModuleInteractorConfig

    private let protectionInteractor: ProtectionInteracting
    private let loginInteractor: LoginInteracting

    init(
        loginConfig: LoginModuleInteractorConfig,
        protectionInteractor: ProtectionInteracting,
        loginInteractor: LoginInteracting
    ) {
        self.loginConfig = loginConfig
        self.protectionInteractor = protectionInteractor
        self.loginInteractor = loginInteractor
    }
}

extension ForgotMasterPasswordRecoveryModuleInteractor: ForgotMasterPasswordRecoveryModuleInteracting {
    var isAppLocked: Bool {
        loginInteractor.isAppLocked
    }

    func validateEntropy(_ entropy: Entropy) -> Bool {
        protectionInteractor.validateEntropyMatchesCurrentVault(entropy)
    }

    @MainActor
    func loginUsingMasterKey(_ masterKey: MasterKey, entropy: Entropy) async -> Bool {
        switch loginConfig.loginType {
        case .login:
            return await loginInteractor.loginUsingMasterKey(masterKey, entropy: entropy)
        case .verify:
            return loginInteractor.verifyMasterKey(masterKey, entropy: entropy)
        case .restore:
            return false
        }
    }
}
