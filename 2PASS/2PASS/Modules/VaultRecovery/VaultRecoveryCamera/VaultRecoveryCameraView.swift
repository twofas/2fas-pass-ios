// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryCameraView: View {

    @State
    var presenter: VaultRecoveryCameraPresenter

    @Environment(\.dismiss)
    private var dismiss

    init(presenter: VaultRecoveryCameraPresenter) {
        self.presenter = presenter
    }

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
                presenter.onToAppSettings()
            }
        )
        .sensoryFeedback(.selection, trigger: presenter.destination?.id)
        .onAppear {
            presenter.onAppear()
        }
        .router(router: VaultRecoveryCameraRouter(), destination: $presenter.destination)
    }
}
