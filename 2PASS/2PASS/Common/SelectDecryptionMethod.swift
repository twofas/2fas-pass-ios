// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct SelectDecryptionMethod: View {
    
    let onFiles: Callback
    let onCamera: Callback
    let onEnterManually: Callback
    
    var body: some View {
        VStack(spacing: Spacing.m) {
            HStack(spacing: 0) {
                Text(T.restoreDecryptVaultOptionTitle.uppercased().localizedKey)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .foregroundStyle(.neutral600)
            
            Button {
                onFiles()
            } label: {
                OptionButtonLabel(
                    title: Text(T.restoreDecryptVaultOptionFile.localizedKey),
                    subtitle: Text(T.restoreDecryptVaultOptionFileDescription.localizedKey),
                    icon: {
                        Image(systemName: "document.fill")
                    }
                )
            }
            .buttonStyle(.option)
            
            Button {
                onCamera()
            } label: {
                OptionButtonLabel(
                    title: Text(T.restoreDecryptVaultOptionScanQr.localizedKey),
                    subtitle: Text(T.restoreDecryptVaultOptionScanQrDescription.localizedKey),
                    icon: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                )
            }
            .buttonStyle(.option)
            
            Button {
                onEnterManually()
            } label: {
                OptionButtonLabel(
                    title: Text(T.restoreDecryptVaultOptionManual.localizedKey),
                    subtitle: Text(T.restoreDecryptVaultOptionManualDescription.localizedKey),
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
