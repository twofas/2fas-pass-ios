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
                        Text(.lockScreenBiometricsPromptFaceidTitle)
                    case .touchID:
                        Text(.lockScreenBiometricsPromptTouchidTitle)
                    case .missing:
                        EmptyView()
                    }
                }
                .font(.title1Emphasized)
                .foregroundStyle(.neutral950)
                
                Text(.lockScreenBiometricsPromptBody)
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }
            
            Spacer()
            
            VStack(spacing: Spacing.s) {
                Button {
                    presenter.onEnable()
                } label: {
                    Text(.lockScreenBiometricsPromptAccept)
                        .accessoryLoader(presenter.isEnabling)
                }
                .allowsHitTesting(presenter.isEnabling == false)
                .buttonStyle(.filled)
                
                Button(.lockScreenBiometricsPromptCancel) {
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
