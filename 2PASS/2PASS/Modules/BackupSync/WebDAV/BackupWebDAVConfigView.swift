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

    var body: some View {
        BackupSyncSettingsDetailsForm(
            kind: .webDAV,
            title: .backupConfigsRowWebdavTitle,
            onSave: {
                hideKeyboard()
                presenter.onSave()
            },
            onClose: {
                hideKeyboard()
                presenter.close()
            }
        ) {
            Section {
                TextField("https://webdav.example.com" as String, text: $presenter.url)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .formFieldChanged(presenter.urlChanged)
            }

            Section(.webdavCredentials) {
                TextField(String(localized: .webdavUsername), text: $presenter.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .textContentType(.username)
                    .formFieldChanged(presenter.usernameChanged)

                SecureInput(label: .webdavPassword, value: $presenter.password)
                    .formFieldChanged(presenter.passwordChanged)
            }
            
            Section(.backupConfigsSecurity) {
                Toggle(.backupConfigsAllowUntrustedCertificates, isOn: $presenter.allowTLSOff)
                    .tint(.accent)
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
        .router(router: BackupWebDAVConfigRouter(), destination: $presenter.destination)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.hideKeyboard()
    }
}
