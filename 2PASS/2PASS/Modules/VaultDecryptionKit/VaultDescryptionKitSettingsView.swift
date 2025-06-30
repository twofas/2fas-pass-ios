// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let qrCodeSpaceMaxHeight = 170.0
    static let qrCodeImageMaxHeight = 225.0
    static let qrCodeImagePositionYMultiplier = 0.55
    static let arrowBottomPadding = 6.0
    static let screenHeight = 700.0
}

struct VaultDescryptionKitSettingsView: View {
    
    @Binding var includeMasterKey: Bool
    
    @Environment(\.dismiss) var dismiss
    
    @State
    private var qrCodeSize: CGSize = .zero
    
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            
            HeaderContentView(
                title: Text(T.decryptionKitSettingsTitle.localizedKey),
                subtitle: Text(T.decryptionKitSettingsDescription.localizedKey)
            )

            Spacer(minLength: Spacing.s)
            
            Color.clear
                .frame(maxHeight: Constants.qrCodeSpaceMaxHeight)
                .overlay(alignment: .top) {
                    GeometryReader { proxy in
                        qrCodeImage
                            .resizable()
                            .scaledToFit()
                            .frame(height: min(Constants.qrCodeImageMaxHeight, proxy.size.height * Constants.qrCodeImageMaxHeight / Constants.qrCodeSpaceMaxHeight))
                            .position(x: proxy.size.width/2, y: proxy.size.height * Constants.qrCodeImagePositionYMultiplier)
                    }
                }
            
            Text(T.decryptionKitSettingsQrLabel.localizedKey)
                .font(.footnote)
                .foregroundStyle(.neutral600)
            
            Image(.vaultDecryptionKitArrow)
                .renderingMode(.template)
                .foregroundStyle(.brand500)
                .padding(.bottom, Constants.arrowBottomPadding)
            
            VStack(spacing: Spacing.s) {
                Text(T.decryptionKitSettingsSecretWordsIos.localizedKey)
                    .font(.subheadline)
                    .foregroundStyle(.neutral950)
                
                Text(T.decryptionKitSettingsMasterKey.localizedKey)
                    .font(.subheadline.bold())
                    .strikethrough(includeMasterKey == false)
                    .foregroundStyle(includeMasterKey ? .neutral950 : .neutral600)
            }
            
            Spacer()
            
            InfoToggle(
                title: Text(T.decryptionKitSettingsToggleTitle.localizedKey),
                description: Text(T.decryptionKitSettingsToggleMsg.localizedKey),
                isOn: $includeMasterKey
            )
            
            Button(T.decryptionKitSettingsCta.localizedKey) {
                dismiss()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.top, Spacing.xll)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xll2)
        .padding(.bottom, Spacing.xl)
        .presentationDetents([.height(Constants.screenHeight)])
        .presentationDragIndicator(.visible)
    }
    
    private var qrCodeImage: Image {
        if includeMasterKey {
            Image(.vaultDecryptionKitQrcodeEncryptionHashOn)
        } else {
            Image(.vaultDecryptionKitQrcodeEncryptionHashOff)
        }
    }
}

#Preview {
    @State @Previewable var includeMasterKey: Bool = false
    
    Color.white
        .sheet(isPresented: .constant(true)) {
            VaultDescryptionKitSettingsView(includeMasterKey: $includeMasterKey)
        }
}
