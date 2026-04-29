// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupWebDAVConfigView: View {

    @State
    var presenter: BackupWebDAVConfigPresenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.settingsCloudSyncWebdavLabel) {
                Section(.webdavServerUrl) {
                    TextField("https://host:port/path/" as String, text: $presenter.url)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .frame(maxWidth: .infinity)

                    Toggle(.webdavAllowUntrustedCertificates, isOn: $presenter.allowTLSOff)
                        .frame(maxWidth: .infinity)
                        .tint(.accentColor)
                }

                Section(.webdavCredentials) {
                    TextField(String(localized: .webdavUsername), text: $presenter.username)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .textContentType(.username)

                    SecureInput(label: .webdavPassword, value: $presenter.password)
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

                if let connectionError = presenter.connectionError {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.destructiveAction)
                        Text(connectionError)
                            .font(.caption)
                            .foregroundStyle(.mainText)
                    }
                }

                Button {
                    presenter.onSave()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if presenter.isTesting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(presenter.isEditMode ? .commonSave : .webdavConnect)
                    }
                }
                .buttonStyle(.filled)
                .disabled(presenter.isTesting)
            }
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.xl)
            .background(Color(UIColor.systemGroupedBackground))
        }
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
