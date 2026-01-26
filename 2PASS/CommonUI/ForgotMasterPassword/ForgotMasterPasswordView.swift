// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ForgotMasterPasswordView: View {

    @State var presenter: ForgotMasterPasswordPresenter

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        VStack {
            HeaderContentView(
                title: Text(.lockScreenForgotMasterPassword),
                subtitle: nil
            )
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
            
            SelectDecryptionMethod(
                onFiles: {},
                onCamera: {}
            )
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .router(router: ForgotMasterPasswordRouter(), destination: $presenter.destination)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    dismiss()
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
    }
}

#Preview {
    ForgotMasterPasswordRouter.buildView()
}
