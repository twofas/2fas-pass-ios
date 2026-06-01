// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UniformTypeIdentifiers
import CommonUI

struct BackupS3ConfigEditorRouter: Router {

    @MainActor
    static func buildView(
        configID: BackupConfig.ID?,
        onClose: @escaping @MainActor (BackupConfig.ID?) -> Void
    ) -> some View {
        BackupS3ConfigEditorView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.backupS3ConfigEditorModuleInteractor(configID: configID),
                configID: configID,
                onClose: onClose
            )
        )
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
