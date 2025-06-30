// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct BiometricPromptViewConstants {
    public static let sheetHeight = 400.0
}

struct BiometricPromptView: View {
    
    @State var presenter: BiometricPromptPresenter
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: Spacing.xll) {
            Group {
                switch presenter.biometryType {
                case .faceID:
                    Image(systemName: "faceid")
                case .touchID:
                    Image(systemName: "touchid")
                case .missing:
                    EmptyView()
                }
            }
            .font(.system(size: 70))
            .foregroundStyle(.accent)
            
            VStack(spacing: Spacing.s) {
                Group {
                    switch presenter.biometryType {
                    case .faceID:
                        Text(T.lockScreenBiometricsPromptFaceidTitle.localizedKey)
                    case .touchID:
                        Text(T.lockScreenBiometricsPromptTouchidTitle.localizedKey)
                    case .missing:
                        EmptyView()
                    }
                }
                .font(.title1Emphasized)
                .foregroundStyle(.neutral950)
                
                Text(T.lockScreenBiometricsPromptBody.localizedKey)
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }
            
            Spacer()
            
            VStack(spacing: Spacing.s) {
                Button {
                    presenter.onEnable()
                } label: {
                    Text(T.lockScreenBiometricsPromptAccept.localizedKey)
                        .accessoryLoader(presenter.isEnabling)
                }
                .allowsHitTesting(presenter.isEnabling == false)
                .buttonStyle(.filled)
                
                Button(T.lockScreenBiometricsPromptCancel.localizedKey) {
                    presenter.onCancel()
                    dismiss()
                }
                .buttonStyle(.twofasBorderless)
            }
            .controlSize(.large)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xxl4)
        .padding(.bottom, Spacing.m)
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            BiometricPromptView(presenter: .init(interactor: ModuleInteractorFactory.shared.biometricPromptModuleInteractor(), onClose: {}))
        }
}
