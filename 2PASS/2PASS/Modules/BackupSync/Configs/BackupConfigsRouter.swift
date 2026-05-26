// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigsRouter: Router {

    /// Stored only to thread `@Namespace` (View-only API) into matched-zoom modifiers.
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
            // Autoclosure overload — the id expression is resolved inside the
            // matched-zoom modifier's body, so observation on the presenter's
            // `savedConfigIDFromPicker` (read through `savedConfigID()`) re-fires
            // the zoom target mid-dismiss. The sheet animates from "+" on open
            // and zooms into the new row after save.
            BackupConfigsAddRouter.buildView(onClose: onClose)
                .matchedZoomDestination(
                    id: savedConfigID().map(Self.editSourceID(for:)) ?? Self.pickerSourceID,
                    in: transitionNamespace
                )

        case .editWebDAV(let configID, let onClose):
            // The zoom modifier wraps the NavigationStack (the sheet's outermost content) so it
            // animates the sheet's presentation from the source row. Applied inside the stack it
            // would act as a push transition — wrong, since the form is the stack's root.
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
