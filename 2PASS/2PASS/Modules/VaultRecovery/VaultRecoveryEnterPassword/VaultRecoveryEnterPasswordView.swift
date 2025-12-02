// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryEnterPasswordView: View {
    private enum FocusedField {
        case password
    }
    
    @Bindable
    var presenter: VaultRecoveryEnterPasswordPresenter
    
    @FocusState
    private var focusedField: FocusedField?
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    VStack(alignment: .center, spacing: Spacing.m) {
                        Asset.smallShield.swiftUIImage
                            .padding(.bottom, Spacing.xl)
                            .padding(.top, Spacing.m)
                        Text(T.restoreVaultVerifyMasterPasswordDescription.localizedKey)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.xll2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(0)
                    .listRowBackground(Color.clear)
                } header: {
                    Spacer(minLength: 0)
                }
                .listSectionSpacing(0)
                
                Section {
                    SecureInput(label: T.masterPasswordLabel.localizedResource, value: $presenter.password)
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            presenter.onDecrypt()
                        }
                        .listRowBackground(Asset.backroundSecondary.swiftUIColor)
                } header: {
                    Spacer(minLength: 0)
                } footer: {
                    Spacer(minLength: 0)
                }
            }
            .scrollContentBackground(.hidden)
            
            VStack {
                Button(T.commonContinue.localizedKey) {
                    presenter.onDecrypt()
                }
                .disabled(!presenter.isPasswordAvailable)
                .buttonStyle(.filled)
                .controlSize(.large)
            }
            .frame(alignment: .bottom)
            .padding(Spacing.m)
        }
        .onAppear {
            presenter.onAppear()
            focusedField = .password
        }
        .router(router: VaultRecoveryEnterPasswordRouter(), destination: $presenter.destination)
        .readableContentMargins()
    }
}
