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
        case .editWebDAV, .editS3:
            .sheet
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupConfigsDestination) -> some View {
        switch destination {
        case .editWebDAV(let configID):
            // The zoom modifier wraps the NavigationStack (the sheet's outermost content) so it
            // animates the sheet's presentation from the source row. Applied inside the stack it
            // would act as a push transition — wrong, since the form is the stack's root.
            zoomable(
                NavigationStack {
                    BackupWebDAVConfigRouter.buildView(configID: configID)
                },
                sourceID: Self.editSourceID(for: configID)
            )

        case .editS3(let configID):
            zoomable(
                NavigationStack {
                    BackupS3ConfigRouter.buildView(configID: configID)
                },
                sourceID: Self.editSourceID(for: configID)
            )

        case .removeConfirmation(_, let onConfirm):
            Button(.commonDelete, role: .destructive, action: onConfirm)
            Button(.commonCancel, role: .cancel) {}
        }
    }

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
