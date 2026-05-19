// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryWebDAVView: View {

    @State
    var presenter: VaultRecoveryWebDAVPresenter

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        BackupConfigEditorForm(
            kind: .webDAV,
            title: .backupConfigsRowWebdavTitle,
            hasUnsavedChanges: presenter.hasUnsavedChanges,
            isSaving: presenter.isFetching,
            canSave: presenter.canSave,
            onSave: {
                hideKeyboard()
                presenter.onSave()
            },
            onClose: {
                hideKeyboard()
                dismiss()
            }
        ) {
            WebDAVFormFields(
                url: $presenter.url,
                username: $presenter.username,
                password: $presenter.password,
                allowTLSOff: $presenter.allowTLSOff
            )
        }
        .confirmLabel(.webdavConnect)
        .cancellable()
        .disabled(presenter.isFetching)
        .router(router: VaultRecoveryWebDAVRouter(), destination: $presenter.destination)
        .onDisappear {
            presenter.onDisappear()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.hideKeyboard()
    }
}
