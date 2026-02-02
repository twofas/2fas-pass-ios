// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

/// Shared container view for recovery kit QR code scanning.
/// Handles camera availability state and displays either the scanning view or a no-access fallback.
public struct RecoveryKitCameraView: View {
    let isCameraAvailable: Bool
    let showInvalidCodeError: Bool
    let onCodeFound: (String) -> Void
    let onCodeLost: () -> Void
    let onAppSettings: () -> Void

    public init(
        isCameraAvailable: Bool,
        showInvalidCodeError: Bool,
        onCodeFound: @escaping (String) -> Void,
        onCodeLost: @escaping () -> Void,
        onAppSettings: @escaping () -> Void
    ) {
        self.isCameraAvailable = isCameraAvailable
        self.showInvalidCodeError = showInvalidCodeError
        self.onCodeFound = onCodeFound
        self.onCodeLost = onCodeLost
        self.onAppSettings = onAppSettings
    }

    public var body: some View {
        Group {
            if isCameraAvailable {
                ScanQRCodeCameraView(
                    title: Text(.restoreQrCodeCameraTitle),
                    description: Text(.restoreQrCodeCameraDescription),
                    error: showInvalidCodeError ? Text(.cameraQrCodeUnsupportedCode) : nil,
                    codeFound: onCodeFound,
                    codeLost: onCodeLost
                )
            } else {
                NoAccessCameraView(onSettings: onAppSettings)
            }
        }
        .colorScheme(.light)
    }
}
