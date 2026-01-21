// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

private struct Constants {
    static let iconFontSize = 49.0
}

struct ChangePasswordConfirmView: View {
    
    let onConfirm: Callback
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: Spacing.s) {
            Spacer()
            
            Image(systemName: "info.circle")
                .font(.system(size: Constants.iconFontSize))
                .padding(.bottom, Spacing.l)
                .foregroundStyle(.brand500)
            
            Text(.setNewPasswordConfirmTitle)
                .font(.title1Emphasized)
                .foregroundStyle(.neutral950)
            
            Text(.setNewPasswordConfirmBodyPart1Ios)
                .font(.subheadline)
                .foregroundStyle(.neutral600)
            
            Text(.setNewPasswordConfirmBodyPart2Ios)
                .font(.subheadline)
                .foregroundStyle(.neutral600)
            
            Spacer()
            
            VStack(spacing: Spacing.m) {
                Button(.commonConfirm) {
                    onConfirm()
                }
                .buttonStyle(.filled)
                
                Button(.commonCancel) {
                    dismiss()
                }
                .buttonStyle(.twofasBorderless)
            }
            .controlSize(.large)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .presentationDetents([.height(500)])
        .presentationDragIndicator(.visible)
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            ChangePasswordConfirmView(onConfirm: {})
        }
}
