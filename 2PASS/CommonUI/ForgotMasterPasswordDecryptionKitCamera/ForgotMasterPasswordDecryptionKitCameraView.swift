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
        Group {
            if presenter.isCameraAvailable {
                ScanQRCodeCameraView(
                    title: Text(.restoreQrCodeCameraTitle),
                    description: Text(.restoreQrCodeCameraDescription),
                    error: presenter.showInvalidCodeError ? Text(.cameraQrCodeUnsupportedCode) : nil,
                    codeFound: { code in
                        presenter.onFoundCode(code: code)
                    },
                    codeLost: {
                        presenter.onCodeLost()
                    }
                )
            } else {
                NoAccessCameraView(onSettings: {
                    presenter.onAppSettings()
                })
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .router(
            router: ForgotMasterPasswordDecryptionKitCameraRouter(),
            destination: $presenter.destination
        )
        .onTapGesture {
            guard !presenter.isCameraAvailable else { return }
            presenter.onAppSettings()
        }
        .colorScheme(.light)
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
