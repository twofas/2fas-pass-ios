// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct ChangePasswordPromptViewConstants {
    static let sheetHeight = 430.0
}

struct ChangePasswordPromptView: View {

    @State var presenter: ChangePasswordPromptPresenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Spacing.xll) {
            Image(.smallShield)
            
            VStack(spacing: Spacing.s) {
                Text(.lockScreenChangePasswordPromptTitle)
                    .font(.title1Emphasized)
                    .foregroundStyle(.neutral950)
                
                Text(.lockScreenChangePasswordPromptBody)
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            VStack(spacing: Spacing.s) {
                Button(.lockScreenChangePasswordPromptAccept) {
                    presenter.onChangePassword()
                }
                .buttonStyle(.filled)
                
                Button(.lockScreenChangePasswordPromptCancel) {
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
        .router(router: ChangePasswordPromptRouter(), destination: $presenter.destination)
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            ChangePasswordPromptView(presenter: .init(
                interactor: ModuleInteractorFactory.shared.changePasswordPromptModuleInteractor(),
                onClose: {}
            ))
        }
}
