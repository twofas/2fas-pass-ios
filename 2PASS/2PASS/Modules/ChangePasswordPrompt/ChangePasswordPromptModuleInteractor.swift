// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol ChangePasswordPromptModuleInteracting: AnyObject {
    func prepareEncryptionDataForPasswordChange() -> Bool
    func clearEncryptionData()
    func finish()
}

final class ChangePasswordPromptModuleInteractor: ChangePasswordPromptModuleInteracting {

    private let protectionInteractor: ProtectionInteracting
    private let loginInteractor: LoginInteracting

    init(protectionInteractor: ProtectionInteracting, loginInteractor: LoginInteracting) {
        self.protectionInteractor = protectionInteractor
        self.loginInteractor = loginInteractor
    }

    func prepareEncryptionDataForPasswordChange() -> Bool {
        protectionInteractor.restoreEntropy()
        protectionInteractor.createSeed()
        protectionInteractor.createSalt()
        return protectionInteractor.entropy != nil && protectionInteractor.salt != nil
    }

    func clearEncryptionData() {
        protectionInteractor.clearAfterInit()
    }

    func finish() {
        loginInteractor.finishRequestForPasswordChange()
    }
}
