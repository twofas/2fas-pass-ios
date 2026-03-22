// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ShareLinkImportPasswordView: View {

    @State var presenter: ShareLinkImportPasswordPresenter

    var body: some View {
        NavigationStack {
            VStack {
                VStack(spacing: Spacing.xll) {
                    Image(.shareStar)
                        .padding(.top, Spacing.xll3)

                    VStack(spacing: Spacing.s) {
                        Text(.shareLinkImportPasswordTitle)
                            .font(.title1Emphasized)
                            .foregroundStyle(.base1000)

                        Text(.shareLinkImportPasswordSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.neutral950)
                    }

                    SharePasswordInput(text: $presenter.password)
                        .errorMessage(presenter.errorDescription)
                        .autoFocus()
                        .onSubmit {
                            presenter.onSubmitPassword()
                        }
                        .padding(.top, Spacing.s)
                        .padding(.horizontal, Spacing.xl)
                }

                Spacer()

                Button(.shareLinkImportUnlock) {
                    presenter.onSubmitPassword()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
                .disabled(presenter.password.isEmpty)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xl)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.onCancel()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    ShareLinkImportPasswordView(
        presenter: ShareLinkImportPasswordPresenter(
            onSubmit: { _ in },
            onClose: {}
        )
    )
}
