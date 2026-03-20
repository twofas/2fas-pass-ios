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
    @State private var didFocus = false
    
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
                    
                    VStack {
                        Section {
                            passwordInput
                        } footer: {
                            errorDescription
                        }
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
    
    @ViewBuilder
    private var passwordInput: some View {
        SecureInput(label: .masterPasswordLabel, value: $presenter.password)
            .introspect { textField in
                guard !didFocus else { return }
                didFocus = true
                textField.becomeFirstResponder()
            }
            .onSubmit {
                presenter.onSubmitPassword()
            }
            .submitLabel(.go)
            .padding(.leading, Spacing.l)
            .padding(.trailing, 11)
            .frame(height: 44.0)
            .background(Color(.secondarySystemGroupedBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 10.0)
                    .stroke(.danger500, lineWidth: presenter.inputError ? 1 : 0)
            }
            .sensoryFeedback(trigger: presenter.inputError, { oldValue, newValue in
                newValue ? .error : nil
            })
            .clipShape(RoundedRectangle(cornerRadius: 10.0))
            .shakeAnimation(trigger: presenter.inputError)
    }
    
    @ViewBuilder
    private var errorDescription: some View {
        ZStack {
            if presenter.errorDescription.isEmpty == false {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.danger500)
                    
                    Text(presenter.errorDescription)
                        .font(.caption1Emphasized)
                        .foregroundStyle(.danger500)
                    
                    Spacer()
                }
                .padding(.horizontal, Spacing.m)
            }
        }
        .animation(nil, value: presenter.errorDescription.isEmpty)
        .frame(minHeight: Spacing.xl)
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
