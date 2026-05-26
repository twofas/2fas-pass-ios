// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigsRouter: Router {

    let transitionNamespace: Namespace.ID?

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
        case .editWebDAV, .editS3, .add:
            .sheet
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupConfigsDestination) -> some View {
        switch destination {
        case .add(let onClose, let savedConfigID):
            BackupConfigsAddRouter.buildView(onClose: onClose)
                .matchedZoomDestination(
                    id: savedConfigID().map(Self.editSourceID(for:)) ?? Self.pickerSourceID,
                    in: transitionNamespace
                )

        case .editWebDAV(let configID, let onClose):
            NavigationStack {
                BackupWebDAVConfigEditorRouter.buildView(configID: configID, onClose: onClose)
            }
            .matchedZoomDestination(id: Self.editSourceID(for: configID), in: transitionNamespace)

        case .editS3(let configID, let onClose):
            NavigationStack {
                BackupS3ConfigEditorRouter.buildView(configID: configID, onClose: onClose)
            }
            .matchedZoomDestination(id: Self.editSourceID(for: configID), in: transitionNamespace)

        case .removeConfirmation(_, let onConfirm):
            Button(.commonDelete, role: .destructive, action: onConfirm)
            Button(.commonCancel, role: .cancel) {}
        }
    }

    static let pickerSourceID = "backupConfigs.add.picker"

    static func editSourceID(for configID: BackupConfig.ID) -> String {
        "backupConfigs.edit.\(configID)"
    }
}
