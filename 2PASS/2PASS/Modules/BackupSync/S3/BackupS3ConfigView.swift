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
    @State private var fieldLabelWidth: CGFloat?

    var body: some View {
        BackupSyncSettingsDetailsForm(
            kind: .s3,
            title: .backupConfigsRowS3Title,
            onSave: {
                hideKeyboard()
                presenter.onSave()
            },
            onClose: {
                hideKeyboard()
                if presenter.isEditMode {
                    dismiss()
                } else {
                    presenter.cancelAndClose()
                }
            }
        ) {
            Section {
                TextField("https://s3.example.com" as String, text: $presenter.endpoint)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .formFieldChanged(presenter.endpointChanged)

                LabeledInput(label: String(localized: .s3Region), fieldWidth: $fieldLabelWidth) {
                    TextField("us-east-1" as String, text: $presenter.region)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.leading, Spacing.s)
                }
                .formFieldChanged(presenter.regionChanged)

                LabeledInput(label: String(localized: .s3Bucket), fieldWidth: $fieldLabelWidth) {
                    TextField("my-bucket" as String, text: $presenter.bucket)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.leading, Spacing.s)
                }
                .formFieldChanged(presenter.bucketChanged)
            }

            Section {
                TextField(String(localized: .s3AccessKeyId), text: $presenter.accessKeyId)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .formFieldChanged(presenter.accessKeyIdChanged)

                SecureInput(label: .s3SecretAccessKey, value: $presenter.secretAccessKey)
                    .formFieldChanged(presenter.secretAccessKeyChanged)
            } header: {
                HStack {
                    Text(.s3Credentials)
                    Spacer()
                    Button(String(localized: .s3LoadFromCsvButton)) {
                        presenter.onLoadFromCSV()
                    }
                    .font(.calloutEmphasized)
                }
            }

            Section(.s3Security) {
                Toggle(.s3AllowUntrustedCertificates, isOn: $presenter.allowTLSOff)
                    .tint(.accentColor)
                    .formFieldChanged(presenter.allowTLSOffChanged)
            }
        }
        .editMode(presenter.isEditMode)
        .unsavedChanges(presenter.hasUnsavedChanges)
        .saving(presenter.isTesting)
        .canSave(presenter.canSave)
        .disabled(presenter.isTesting)
        .sensoryFeedback(.success, trigger: presenter.successFeedbackTrigger)
        .sensoryFeedback(.error, trigger: presenter.failureFeedbackTrigger)
        .router(router: BackupS3ConfigRouter(), destination: $presenter.destination)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.cancelTest()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.hideKeyboard()
    }
}

#Preview {
    BackupS3ConfigRouter.buildView(configID: nil)
}
