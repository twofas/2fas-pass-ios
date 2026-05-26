// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupWebDAVConfigEditorRouter: Router {

    @MainActor
    static func buildView(
        configID: BackupConfig.ID?,
        onClose: @escaping @MainActor (BackupConfig.ID?) -> Void
    ) -> some View {
        BackupWebDAVConfigEditorView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.backupWebDAVConfigEditorModuleInteractor(configID: configID),
                configID: configID,
                onClose: onClose
            )
        )
    }

    func routingType(for destination: BackupWebDAVConfigEditorDestination?) -> RoutingType? {
        switch destination {
        case .errorAlert(let message):
            .alert(title: String(localized: .commonError), message: message)
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupWebDAVConfigEditorDestination) -> some View {
        EmptyView()
    }
}
