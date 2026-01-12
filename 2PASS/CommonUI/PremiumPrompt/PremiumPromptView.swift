// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct PremiumPromptViewConstants {
    public static let sheetHeight = 400.0
}

struct PremiumPromptView: View {
    
    let title: Text
    let description: Text
        
    @State
    var presenter: PremiumPromptPresenter
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: Spacing.xll) {
            Image(._2PASSShield)
            
            VStack(spacing: Spacing.s) {
                title
                    .font(.title1Emphasized)
                    .foregroundStyle(.neutral950)
                
                description
                    .lineLimit(3)
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
            
            if presenter.allowsUpgrade {
                VStack(spacing: Spacing.s) {
                    Button(.paywallNoticeCta) {
                        dismiss()
                        
                        Task {
                            try await Task.sleep(for: .milliseconds(700))
                            presenter.onUpgrade()
                        }
                    }
                    .buttonStyle(.filled)
                    
                    Button(.commonCancel) {
                        dismiss()
                    }
                    .buttonStyle(.twofasBorderless)
                }
                .controlSize(.large)
            } else {
                Button(.commonClose) {
                    dismiss()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.xxl4)
        .padding(.bottom, Spacing.m)
        .presentationDetents([.height(PremiumPromptViewConstants.sheetHeight)])
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PremiumPromptView(
                title: Text(.paywallNoticeBrowsersLimitTitle),
                description: Text(.paywallNoticeBrowsersLimitMsg),
                presenter: .init(interactor: ModuleInteractorFactory.shared.premiumPromptModuleInteractor())
            )
            .presentationDetents([.height(PremiumPromptViewConstants.sheetHeight)])
        }
}
