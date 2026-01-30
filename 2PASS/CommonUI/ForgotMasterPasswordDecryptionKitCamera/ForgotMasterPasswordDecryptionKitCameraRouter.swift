// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct ForgotMasterPasswordDecryptionKitCameraRouter: Router {

    @ViewBuilder
    public static func buildView(
        config: LoginModuleInteractorConfig,
        onSuccess: @escaping Callback,
        onTryAgain: @escaping Callback,
        onClose: @escaping Callback
    ) -> some View {
        let presenter = ForgotMasterPasswordDecryptionKitCameraPresenter(
            interactor: ModuleInteractorFactory.shared.forgotMasterPasswordDecryptionKitCameraModuleInteractor(),
            config: config,
            onSuccess: onSuccess,
            onTryAgain: onTryAgain,
            onClose: onClose
        )
        ForgotMasterPasswordDecryptionKitCameraView(
            presenter: presenter
        )
    }
    
    @ViewBuilder
    public func view(for destination: ForgotMasterPasswordDecryptionKitCameraDestination) -> some View {
        switch destination {
        case .recovery(let entropy, let masterKey, let config, let onSuccess, let onTryAgain, let onClose):
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
    
    public func routingType(for destination: ForgotMasterPasswordDecryptionKitCameraDestination?) -> RoutingType? {
        switch destination {
        case .recovery: .push
        case nil: nil
        }
    }
}
