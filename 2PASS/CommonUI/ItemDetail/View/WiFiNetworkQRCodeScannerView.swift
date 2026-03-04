// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct WiFiNetworkQRCodeScannerView: View {

    @State
    var presenter: WiFiNetworkQRCodeScannerPresenter

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if presenter.isCameraAvailable {
                    ScanQRCodeCameraView(
                        title: Text(.wifiQrScanTitle),
                        error: presenter.showInvalidCodeError ? Text(.cameraQrCodeUnsupportedCode) : nil,
                        codeFound: { code in
                            presenter.onCodeFound(code)
                        },
                        codeLost: {
                            presenter.onCodeLost()
                        }
                    )
                } else {
                    NoAccessCameraView(onSettings: presenter.onAppSettings)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .onChange(of: presenter.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }
}
