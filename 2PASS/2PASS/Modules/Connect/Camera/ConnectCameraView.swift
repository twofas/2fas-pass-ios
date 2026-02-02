// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import CommonUI
import Common

struct ConnectCameraView: View {
    
    @State
    var presenter: ConnectCameraPresenter
        
    var body: some View {
        ScanQRCodeCameraView(
            title: Text(.restoreQrCodeCameraTitle),
            description: Text(.connectQrcodeCameraDescription),
            error: presenter.showInvalidCodeError ? Text(.cameraQrCodeUnsupportedCode) : nil,
            codeFound: {
                presenter.onScannedQRCode($0)
            },
            codeLost: {
                presenter.onCodeLost()
            }
        )
        .sensoryFeedback(.selection, trigger: presenter.destination?.id)
        .router(router: ConnectCameraRouter(), destination: $presenter.destination)
        .onAppear {
            presenter.onAppear()
        }
    }
}

#Preview {
    ConnectCameraView(presenter: .init(onScannedQRCode: {}, onScanAgain: {}))
}
