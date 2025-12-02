// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupAddWebDAVView: View {
    
    @State
    var presenter: BackupAddWebDAVPresenter

    @Environment(\.dismiss) private var dismiss
        
    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(T.settingsEntryWebdav.localizedKey) {
                Section(T.webdavServerUrl.localizedKey) {
                    TextField("https://host:port/path/" as String, text: $presenter.url)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .frame(maxWidth: .infinity)
                        .disabled(!presenter.isEditable)
                    Toggle(T.webdavAllowUntrustedCertificates.localizedKey, isOn: $presenter.allowTLSOff)
                        .frame(maxWidth: .infinity)
                        .disabled(!presenter.isEditable)
                        .tint(.accentColor)
                }
                
                Section(T.webdavCredentials.localizedKey) {
                    TextField(T.webdavUsername.localizedKey, text: $presenter.username)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .disabled(!presenter.isEditable)
                    
                    SecureInput(label: T.webdavPassword.localizedResource, value: $presenter.password)
                        .disabled(!presenter.isEditable)
                }
  
            } header: {
                HStack {
                    Spacer()
                    Text(T.settingsCloudSyncWebdavLabel.localizedKey)
                        .font(.title1Emphasized)
                        .foregroundStyle(Color.neutral950)
                        .padding(.bottom, Spacing.xll3)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .settingsFormNavigationBarTitleHidden(true)
            }
            
            VStack(spacing: Spacing.l) {
                if let uriError = presenter.uriError {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Asset.destructiveActionColor.swiftUIColor)
                        Text(uriError)
                            .font(.caption)
                            .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                    }
                }
                
                if presenter.isConnected {
                    Button(T.webdavDisconnect.localizedKey, role: .destructive) {
                        presenter.onDisconnect()
                    }
                    .buttonStyle(.filled)
                } else {
                    Button {
                        presenter.onConnect()
                    } label: {
                        Text(presenter.isLoading ? T.webdavConnecting.localizedKey : T.webdavConnect.localizedKey)
                            .accessoryLoader(presenter.isLoading)
                    }
                    .allowsHitTesting(presenter.isLoading == false)
                    .buttonStyle(.filled)
                }
            }
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .router(router: BackupAddWebDAVRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        BackupAddWebDAVRouter.buildView()
    }
}
