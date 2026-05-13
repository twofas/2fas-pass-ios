// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupWebDAVConfigRouter: Router {

    /// Constructs the form. When `onClose` is provided the caller takes full ownership of
    /// the close path (including dismissal); when omitted the container falls back to
    /// dismissing via `\.dismiss`, matching the edit-from-row behavior.
    @MainActor
    static func buildView(
        configID: BackupConfig.ID?,
        onClose: ((BackupConfig.ID?) -> Void)? = nil
    ) -> some View {
        BackupWebDAVConfigContainerView(configID: configID, onClose: onClose)
    }

    func routingType(for destination: BackupWebDAVConfigDestination?) -> RoutingType? {
        switch destination {
        case .errorAlert(let message):
            .alert(title: String(localized: .commonError), message: message)
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupWebDAVConfigDestination) -> some View {
        EmptyView()
    }
}

private struct BackupWebDAVConfigContainerView: View {
    let configID: BackupConfig.ID?
    let onClose: ((BackupConfig.ID?) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BackupWebDAVConfigView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.backupWebDAVConfigModuleInteractor(configID: configID),
                configID: configID,
                onClose: onClose ?? { _ in dismiss() }
            )
        )
    }
}
