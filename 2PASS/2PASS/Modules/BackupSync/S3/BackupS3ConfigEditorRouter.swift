// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UniformTypeIdentifiers
import CommonUI

struct BackupS3ConfigEditorRouter: Router {

    /// Constructs the form. When `onClose` is provided the caller takes full ownership of
    /// the close path (including dismissal); when omitted the container falls back to
    /// dismissing via `\.dismiss`, matching the edit-from-row behavior.
    @MainActor
    static func buildView(
        configID: BackupConfig.ID?,
        onClose: ((BackupConfig.ID?) -> Void)? = nil
    ) -> some View {
        BackupS3ConfigEditorContainerView(configID: configID, onClose: onClose)
    }

    func routingType(for destination: BackupS3ConfigEditorDestination?) -> RoutingType? {
        switch destination {
        case .errorAlert(let message):
            .alert(title: String(localized: .commonError), message: message)
        case .loadSecretsFromCSV(let onClose):
            .fileImporter(contentTypes: [.commaSeparatedText], onClose: onClose)
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupS3ConfigEditorDestination) -> some View {
        EmptyView()
    }
}

private struct BackupS3ConfigEditorContainerView: View {
    let configID: BackupConfig.ID?
    let onClose: ((BackupConfig.ID?) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BackupS3ConfigEditorView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.backupS3ConfigEditorModuleInteractor(configID: configID),
                configID: configID,
                onClose: onClose ?? { _ in dismiss() }
            )
        )
    }
}
