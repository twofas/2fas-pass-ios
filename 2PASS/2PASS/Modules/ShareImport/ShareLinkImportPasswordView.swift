// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI
import Data

struct ShareLinkImportPasswordView: View {

    @Bindable var presenter: ShareLinkImportPresenter

    var body: some View {
        NavigationStack {
            VStack {
                VStack(spacing: 24) {
                    Image(.shareStar)
                        .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text(.shareLinkImportPasswordTitle)
                            .font(.title1Emphasized)
                            .foregroundStyle(.base1000)

                        Text("Secure your 2FAS Share link")
                            .font(.subheadline)
                            .foregroundStyle(.neutral950)
                    }

                    SharePasswordInput(text: $presenter.password)
                        .errorMessage(presenter.inputError ? presenter.errorDescription : nil)
                        .autoFocus()
                        .onSubmit {
                            presenter.onSubmitPassword()
                        }
                        .padding(.top, 8)
                        .padding(.horizontal, Spacing.xl)
                }

                Spacer()

                Button(.shareLinkImportUnlock) {
                    presenter.onSubmitPassword()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
                .disabled(presenter.password.isEmpty || presenter.isDecrypting)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.onEditorClosed(.failure(.userCancelled))
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    ShareLinkImportPasswordView(
        presenter: ShareLinkImportPresenter(
            components: ShareLinkComponents(
                id: "preview",
                nonce: Data(),
                encryption: .password(salt: Data())
            ),
            interactor: ModuleInteractorFactory.shared.shareLinkImportModuleInteractor(),
            onDismiss: {}
        )
    )
}
