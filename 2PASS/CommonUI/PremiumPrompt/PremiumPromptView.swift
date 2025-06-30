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
            
            VStack(spacing: Spacing.s) {
                Button(T.paywallNoticeCta.localizedKey) {
                    dismiss()
                    
                    Task {
                        presenter.onUpgrade()
                    }
                }
                .buttonStyle(.filled)
                
                Button(T.commonCancel.localizedKey) {
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
        .presentationDetents([.height(PremiumPromptViewConstants.sheetHeight)])
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PremiumPromptView(
                title: Text("Can't Transfer Items"),
                description: Text("You have reached You have reached You have reached You have reached You have reached You have reached You have reached You have reached You have reached You have reached You have reached You have reached"),
                presenter: .init()
            )
            .presentationDetents([.height(PremiumPromptViewConstants.sheetHeight)])
        }
}
