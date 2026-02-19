// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ForgotMasterPasswordDecryptionKitCameraView: View {
    
    @State
    var presenter: ForgotMasterPasswordDecryptionKitCameraPresenter

    var body: some View {
        RecoveryKitCameraView(
            isCameraAvailable: presenter.isCameraAvailable,
            showInvalidCodeError: presenter.showInvalidCodeError,
            onCodeFound: { code in
                presenter.onFoundCode(code: code)
            },
            onCodeLost: {
                presenter.onCodeLost()
            },
            onAppSettings: {
                presenter.onAppSettings()
            }
        )
        .sensoryFeedback(.selection, trigger: presenter.destination?.id)
        .onAppear {
            presenter.onAppear()
        }
        .router(
            router: ForgotMasterPasswordDecryptionKitCameraRouter(),
            destination: $presenter.destination
        )
    }
}

#Preview {
    ForgotMasterPasswordDecryptionKitCameraView(
        presenter: .init(
            interactor: ModuleInteractorFactory.shared.forgotMasterPasswordDecryptionKitCameraModuleInteractor(),
            config: .init(allowBiometrics: false, loginType: .login),
            onSuccess: {},
            onTryAgain: {},
            onClose: {}
        )
    )
}
