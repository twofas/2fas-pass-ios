// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupWebDAVConfigEditorView: View {

    @State
    var presenter: BackupWebDAVConfigEditorPresenter

    var body: some View {
        BackupConfigEditorForm(
            kind: .webDAV,
            title: .backupConfigsRowWebdavTitle,
            hasUnsavedChanges: presenter.hasUnsavedChanges,
            isSaving: presenter.isTesting,
            canSave: presenter.canSave,
            onSave: {
                hideKeyboard()
                presenter.onSave()
            },
            onClose: {
                hideKeyboard()
                presenter.close()
            }
        ) {
            WebDAVFormFields(
                url: $presenter.url,
                username: $presenter.username,
                password: $presenter.password,
                allowTLSOff: $presenter.allowTLSOff
            )
            .formFieldChanged(url: presenter.urlChanged)
            .formFieldChanged(username: presenter.usernameChanged)
            .formFieldChanged(password: presenter.passwordChanged)
            .formFieldChanged(allowTLSOff: presenter.allowTLSOffChanged)
        }
        .editMode(presenter.isEditMode)
        .disabled(presenter.isTesting)
        .sensoryFeedback(.success, trigger: presenter.successFeedbackTrigger)
        .sensoryFeedback(.error, trigger: presenter.failureFeedbackTrigger)
        .router(router: BackupWebDAVConfigEditorRouter(), destination: $presenter.destination)
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
