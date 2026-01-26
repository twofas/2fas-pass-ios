// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct SelectDecryptionMethod: View {
    
    private let onFiles: Callback
    private let onCamera: Callback
    private let onEnterManually: Callback?
    
    public init(
        onFiles: @escaping Callback,
        onCamera: @escaping Callback,
        onEnterManually: Callback? = nil
    ) {
        self.onFiles = onFiles
        self.onCamera = onCamera
        self.onEnterManually = onEnterManually
    }
    
    public var body: some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: 0) {
                Text(.restoreDecryptVaultOptionTitle)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .foregroundStyle(.neutral600)
            
            Button {
                onFiles()
            } label: {
                OptionButtonLabel(
                    title: Text(.restoreDecryptVaultOptionFile),
                    subtitle: Text(.restoreDecryptVaultOptionFileDescription),
                    icon: {
                        if #available(iOS 18, *) {
                            Image(systemName: "document.fill")
                        } else {
                            Image(systemName: "doc.fill")
                        }
                    }
                )
            }
            .buttonStyle(.option)
            
            Button {
                onCamera()
            } label: {
                OptionButtonLabel(
                    title: Text(.restoreDecryptVaultOptionScanQr),
                    subtitle: Text(.restoreDecryptVaultOptionScanQrDescription),
                    icon: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                )
            }
            .buttonStyle(.option)
            
            if let onEnterManually {
                Button {
                    onEnterManually()
                } label: {
                    OptionButtonLabel(
                        title: Text(.restoreDecryptVaultOptionManual),
                        subtitle: Text(.restoreDecryptVaultOptionManualDescription),
                        icon: {
                            Image(.manualInputIcon)
                                .renderingMode(.template)
                        }
                    )
                }
                .buttonStyle(.option)
            }
        }
    }
}
