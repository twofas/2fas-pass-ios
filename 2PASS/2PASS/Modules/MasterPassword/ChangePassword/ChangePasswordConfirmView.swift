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
            
            Text(T.setNewPasswordConfirmTitle.localizedKey)
                .font(.title1Emphasized)
                .foregroundStyle(.neutral950)
            
            Text(T.setNewPasswordConfirmBodyPart1Ios.localizedKey)
                .font(.subheadline)
                .foregroundStyle(.neutral600)
            
            Text(T.setNewPasswordConfirmBodyPart2Ios.localizedKey)
                .font(.subheadline)
                .foregroundStyle(.neutral600)
            
            Spacer()
            
            VStack(spacing: Spacing.m) {
                Button(T.commonConfirm.localizedKey) {
                    onConfirm()
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
