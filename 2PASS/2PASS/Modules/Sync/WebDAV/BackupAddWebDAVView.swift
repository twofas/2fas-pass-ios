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
            SettingsDetailsForm(.settingsEntryWebdav) {
                Section(.webdavServerUrl) {
                    TextField("https://host:port/path/" as String, text: $presenter.url)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .frame(maxWidth: .infinity)
                        .disabled(!presenter.isEditable)
                    Toggle(.webdavAllowUntrustedCertificates, isOn: $presenter.allowTLSOff)
                        .frame(maxWidth: .infinity)
                        .disabled(!presenter.isEditable)
                        .tint(.accentColor)
                }
                
                Section(.webdavCredentials) {
                    TextField(String(localized:.webdavUsername), text: $presenter.username)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)
                        .disabled(!presenter.isEditable)
                    
                    SecureInput(label: .webdavPassword, value: $presenter.password)
                        .disabled(!presenter.isEditable)
                }
  
            } header: {
                HStack {
                    Spacer()
                    Text(.settingsCloudSyncWebdavLabel)
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
                            .foregroundStyle(.destructiveAction)
                        Text(uriError)
                            .font(.caption)
                            .foregroundStyle(.mainText)
                    }
                }
                
                if presenter.isConnected {
                    Button(.webdavDisconnect, role: .destructive) {
                        presenter.onDisconnect()
                    }
                    .buttonStyle(.filled)
                } else {
                    Button {
                        presenter.onConnect()
                    } label: {
                        Text(presenter.isLoading ? .webdavConnecting : .webdavConnect)
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
