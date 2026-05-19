// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupS3ConfigEditorView: View {

    @State
    var presenter: BackupS3ConfigEditorPresenter

    var body: some View {
        BackupConfigEditorForm(
            kind: .s3,
            title: .backupConfigsRowS3Title,
            onSave: {
                hideKeyboard()
                presenter.onSave()
            },
            onClose: {
                hideKeyboard()
                presenter.close()
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
            .formFieldChanged(endpoint: presenter.endpointChanged)
            .formFieldChanged(region: presenter.regionChanged)
            .formFieldChanged(bucket: presenter.bucketChanged)
            .formFieldChanged(accessKeyId: presenter.accessKeyIdChanged)
            .formFieldChanged(secretAccessKey: presenter.secretAccessKeyChanged)
            .formFieldChanged(allowTLSOff: presenter.allowTLSOffChanged)
        }
        .editMode(presenter.isEditMode)
        .unsavedChanges(presenter.hasUnsavedChanges)
        .isSaving(presenter.isTesting)
        .canSave(presenter.canSave)
        .disabled(presenter.isTesting)
        .sensoryFeedback(.success, trigger: presenter.successFeedbackTrigger)
        .sensoryFeedback(.error, trigger: presenter.failureFeedbackTrigger)
        .router(router: BackupS3ConfigEditorRouter(), destination: $presenter.destination)
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

#Preview {
    BackupS3ConfigEditorRouter.buildView(configID: nil, onClose: { _ in })
}
