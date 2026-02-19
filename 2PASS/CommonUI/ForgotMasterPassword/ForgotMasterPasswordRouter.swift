// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ForgotMasterPasswordRouter: Router {

    static func buildView(
        config: LoginModuleInteractorConfig,
        onSuccess: @escaping Callback,
        onClose: @escaping Callback
    ) -> some View {
        NavigationStack {
            ForgotMasterPasswordView(
                presenter: .init(
                    interactor: ModuleInteractorFactory.shared.forgotMasterPasswordModuleInteractor(config: config),
                    onSuccess: onSuccess,
                    onClose: onClose
                )
            )
        }
        .background(.background)
    }

    @ViewBuilder
    func view(for destination: ForgotMasterPasswordDestination) -> some View {
        switch destination {
        case .errorOpeningFile(_, let onClose):
            Button(.commonOk, action: onClose)
        case .camera(let config, let onSuccess, let onTryAgain, let onClose):
            ForgotMasterPasswordDecryptionKitCameraRouter.buildView(
                config: config,
                onSuccess: onSuccess,
                onTryAgain: onTryAgain,
                onClose: onClose
            )
        case .recovery(let config, let entropy, let masterKey, let onSuccess, let onTryAgain, let onClose):
            ForgotMasterPasswordRecoveryRouter.buildView(
                config: config,
                entropy: entropy,
                masterKey: masterKey,
                onSuccess: onSuccess,
                onTryAgain: onTryAgain,
                onClose: onClose
            )
        }
    }

    func routingType(for destination: ForgotMasterPasswordDestination?) -> RoutingType? {
        switch destination {
        case .errorOpeningFile(let message, _):
            return .alert(title: String(localized: .commonError), message: message)
        case .camera:
            return .push
        case .recovery:
            return .push
        case nil:
            return nil
        }
    }
}
