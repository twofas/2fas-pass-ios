// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryS3View: View {

    @State
    var presenter: VaultRecoveryS3Presenter

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        BackupConfigEditorForm(
            kind: .s3,
            title: .backupConfigsProviderS3Title,
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
            S3FormFields(
                endpoint: $presenter.endpoint,
                region: $presenter.region,
                bucket: $presenter.bucket,
                accessKeyId: $presenter.accessKeyId,
                secretAccessKey: $presenter.secretAccessKey,
                allowTLSOff: $presenter.allowTLSOff,
                onLoadFromCSV: { presenter.onLoadFromCSV() }
            )
        }
        .confirmLabel(.s3Connect)
        .cancellable()
        .disabled(presenter.isFetching)
        .router(router: VaultRecoveryS3Router(), destination: $presenter.destination)
        .onDisappear {
            presenter.onDisappear()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.hideKeyboard()
    }
}
