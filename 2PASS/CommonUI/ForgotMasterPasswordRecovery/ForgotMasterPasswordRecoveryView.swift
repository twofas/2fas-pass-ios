// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ForgotMasterPasswordRecoveryView: View {

    @State
    var presenter: ForgotMasterPasswordRecoveryPresenter

    var body: some View {
        Group {
            switch presenter.result {
            case .success:
                ResultView(
                    kind: .success,
                    title: Text(.forgotMasterPasswordVerificationSuccessTitle),
                    action: {
                        Button(.commonClose, action: presenter.handleSuccess)
                    }
                )
            case .failure(.missingMasterKey):
                ResultView(
                    kind: .failure,
                    title: Text(.forgotMasterPasswordNoMasterKeyTitle),
                    description: Text(.forgotMasterPasswordNoMasterKeySubtitle),
                    action: {
                        Button(.commonTryAgain, action: presenter.handleTryAgain)
                    }
                )
            case .failure(.appLocked):
                ResultView(
                    kind: .failure,
                    title: Text(.forgotMasterPasswordErrorVerificationTitle),
                    description: Text(.forgotMasterPasswordErrorVerificationSubtitle),
                    action: {
                        Button(.commonClose, action: presenter.handleClose)
                    }
                )
            case .failure:
                ResultView(
                    kind: .failure,
                    title: Text(.forgotMasterPasswordErrorVerificationTitle),
                    description: Text(.forgotMasterPasswordErrorVerificationSubtitle),
                    action: {
                        Button(.commonTryAgain, action: presenter.handleTryAgain)
                    }
                )
            case nil:
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    ForgotMasterPasswordRecoveryRouter.buildView(
        config: .init(allowBiometrics: false, loginType: .login),
        entropy: Data(),
        masterKey: Data(),
        onSuccess: {},
        onTryAgain: {},
        onClose: {}
    )
}
