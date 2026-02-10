// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data

struct ForgotMasterPasswordRecoveryRouter {

    static func buildView(
        config: LoginModuleInteractorConfig,
        entropy: Entropy,
        masterKey: MasterKey?,
        onSuccess: @escaping Callback,
        onTryAgain: @escaping Callback,
        onClose: @escaping Callback
    ) -> some View {
        ForgotMasterPasswordRecoveryView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.forgotMasterPasswordRecoveryModuleInteractor(config: config),
                entropy: entropy,
                masterKey: masterKey,
                onSuccess: onSuccess,
                onTryAgain: onTryAgain,
                onClose: onClose
            )
        )
    }

}
