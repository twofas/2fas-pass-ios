// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigsRouter: Router {

    var transitionNamespace: Namespace.ID?

    @MainActor
    static func buildView() -> some View {
        BackupConfigsView(
            presenter: .init(interactor: ModuleInteractorFactory.shared.backupConfigsModuleInteractor())
        )
    }

    func routingType(for destination: BackupConfigsDestination?) -> RoutingType? {
        switch destination {
        case .removeConfirmation(let name, _):
            .alert(
                title: String(localized: .backupConfigsRemoveConfirmTitle(name)),
                message: String(localized: .backupConfigsRemoveConfirmBody)
            )
        case .addWebDAV, .addS3, .editWebDAV, .editS3:
            .sheet
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupConfigsDestination) -> some View {
        switch destination {
        case .addWebDAV:
            zoomable(BackupWebDAVConfigRouter.buildView(configID: nil), sourceID: Self.addWebDAVSourceID)

        case .addS3:
            zoomable(BackupS3ConfigRouter.buildView(configID: nil), sourceID: Self.addS3SourceID)

        case .editWebDAV(let configID):
            zoomable(BackupWebDAVConfigRouter.buildView(configID: configID), sourceID: Self.editSourceID(for: configID))

        case .editS3(let configID):
            zoomable(BackupS3ConfigRouter.buildView(configID: configID), sourceID: Self.editSourceID(for: configID))

        case .removeConfirmation(_, let onConfirm):
            Button(.commonDelete, role: .destructive, action: onConfirm)
            Button(.commonCancel, role: .cancel) {}
        }
    }

    static let addWebDAVSourceID = "backupConfigs.add.webdav"
    static let addS3SourceID = "backupConfigs.add.s3"

    static func editSourceID(for configID: UUID) -> String {
        "backupConfigs.edit.\(configID)"
    }

    @ViewBuilder
    private func zoomable<V: View>(_ view: V, sourceID: String) -> some View {
        if #available(iOS 26.0, *), let transitionNamespace {
            view.navigationTransition(.zoom(sourceID: sourceID, in: transitionNamespace))
        } else {
            view
        }
    }
}
