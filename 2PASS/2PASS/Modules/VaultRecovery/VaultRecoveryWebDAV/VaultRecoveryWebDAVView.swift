// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryWebDAVView: View {
    
    @State
    var presenter: VaultRecoveryWebDAVPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                HStack {
                    Spacer()
                    Text(.settingsCloudSyncWebdavLabel)
                        .font(.title1Emphasized)
                        .foregroundStyle(Color.neutral950)
                        .padding(.bottom, Spacing.xll3)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                
                Section(.webdavServerUrl) {
                    TextField("https://host:port/path/" as String, text: $presenter.url)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .frame(maxWidth: .infinity)
                        .disabled(presenter.isLoading)
                    
                    Toggle(.webdavAllowUntrustedCertificates, isOn: $presenter.allowTLSOff)
                        .frame(maxWidth: .infinity)
                        .tint(.accentColor)
                }
                
                
                Section(.webdavCredentials) {
                    TextField(String(localized: .webdavUsername), text: $presenter.username)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .disabled(presenter.isLoading)
                    
                    SecureInput(label: .webdavPassword, value: $presenter.password)
                        .disabled(presenter.isLoading)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollReadableContentMargins()
            
            VStack(spacing: Spacing.l) {
                Button {
                    presenter.onConnect()
                } label: {
                    Text(presenter.isLoading ? .webdavConnecting : .commonContinue)
                        .accessoryLoader(presenter.isLoading)
                }
                .buttonStyle(.filled)
                .allowsHitTesting(presenter.isLoading == false)
            }
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl)
            .readableContentMargins()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .router(router: VaultRecoveryWebDAVRouter(), destination: $presenter.destination)
        .onDisappear {
            presenter.onDisappear()
        }
    }
}
