// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupS3ConfigView: View {

    @State
    var presenter: BackupS3ConfigPresenter

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.backupConfigsRowS3Title) {
                Section(.s3Endpoint) {
                    TextField("https://s3.example.com" as String, text: $presenter.endpoint)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)

                    TextField(String(localized: .s3Region), text: $presenter.region)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField(String(localized: .s3Bucket), text: $presenter.bucket)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Toggle(.s3AllowUntrustedCertificates, isOn: $presenter.allowTLSOff)
                        .tint(.accentColor)
                }

                Section(.s3Credentials) {
                    TextField(String(localized: .s3AccessKeyId), text: $presenter.accessKeyId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    SecureInput(label: .s3SecretAccessKey, value: $presenter.secretAccessKey)
                }
            } header: {
                HStack {
                    Spacer()
                    Text(.backupConfigsRowS3Title)
                        .font(.title1Emphasized)
                        .foregroundStyle(Color.neutral950)
                        .padding(.bottom, Spacing.xll3)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .settingsFormNavigationBarTitleHidden(true)
            }

            VStack(spacing: Spacing.l) {
                if let validationError = presenter.validationError {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.destructiveAction)
                        Text(validationError)
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
                        Text(presenter.isEditMode ? .commonSave : .s3Connect)
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
