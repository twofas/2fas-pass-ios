// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryScanQRCodeIntroView: View {
    
    @State
    var presenter: VaultRecoveryScanQRCodeIntroPresenter
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    var body: some View {
        VStack {
            HeaderContentView(
                title: Text(.restoreQrCodeIntroTitle),
                subtitle: Text(.restoreQrCodeIntroDescription),
                icon: {
                    Image(.lockFileHeaderIcon)
                }
            )
            
            Spacer()
            
            Image(.vaultDecryptionKitFullDocument)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .background {
                    RoundedRectangle(cornerRadius: 16.0)
                        .fill(.neutral50)
                        .stroke(colorScheme == .dark ? .neutral200 : .neutral100, lineWidth: 0.5)
                }
            
            Spacer()
            
            Button(.restoreQrCodeIntroCta) {
                presenter.onContinue()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
        }
        .padding(.vertical, Spacing.l)
        .padding(.horizontal, Spacing.xl)
        .navigationTitle(.restoreDecryptVaultOptionScanQr)
        .navigationBarTitleDisplayMode(.inline)
        .router(router: VaultRecoveryScanQRCodeIntroRouter(), destination: $presenter.destination)
        .readableContentMargins()
    }
}
