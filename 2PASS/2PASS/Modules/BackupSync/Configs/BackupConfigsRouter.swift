// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigsRouter: Router {

    var transitionNamespace: Namespace.ID?
    /// Held so `view(for: .add)` can read `savedConfigIDFromPicker` and drive the
    /// matched-zoom destination ID reactively. The Router struct is rebuilt on every
    /// parent re-render, so the ref is always fresh; observation tracking on the
    /// `@Observable` presenter re-runs the sheet body when the saved ID changes.
    var presenter: BackupConfigsPresenter?

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
        case .add(let onClose):
            // Reading `presenter?.savedConfigIDFromPicker` here participates in observation
            // tracking inside the sheet content closure, so the matched-zoom destination ID
            // flips from `pickerSourceID` to the saved-row id as soon as the presenter
            // writes it (before the sheet animates away).
            BackupConfigsAddRouter.buildView(onClose: onClose)
                .presentationDetents([.large])
                .matchedZoomDestination(id: zoomDestinationID, in: transitionNamespace)

        case .editWebDAV(let configID):
            // The zoom modifier wraps the NavigationStack (the sheet's outermost content) so it
            // animates the sheet's presentation from the source row. Applied inside the stack it
            // would act as a push transition — wrong, since the form is the stack's root.
            NavigationStack {
                BackupWebDAVConfigRouter.buildView(configID: configID)
            }
            .matchedZoomDestination(id: Self.editSourceID(for: configID), in: transitionNamespace)

        case .editS3(let configID):
            NavigationStack {
                BackupS3ConfigRouter.buildView(configID: configID)
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

    @MainActor
    private var zoomDestinationID: String {
        if let saved = presenter?.savedConfigIDFromPicker {
            return Self.editSourceID(for: saved)
        }
        return Self.pickerSourceID
    }
}
