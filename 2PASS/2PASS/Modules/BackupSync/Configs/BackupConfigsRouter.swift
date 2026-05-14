// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigsRouter: Router {

    var transitionNamespace: Namespace.ID?
    /// Held so `view(for: .picker)` can read `savedConfigIDFromPicker` and drive the
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
        case .add:
            if let presenter {
                pickerView(presenter: presenter)
            }

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

    @MainActor @ViewBuilder
    private func pickerView(presenter: BackupConfigsPresenter) -> some View {
        PickerSheet(presenter: presenter, transitionNamespace: transitionNamespace)
    }
}

/// Wraps the picker sheet content so `@Environment(\.dismiss)` is captured at the sheet
/// root and the close closure (write the saved id → dismiss) can be composed once and
/// injected into `BackupConfigsAddRouter.buildView(onClose:)`. The presenter is read
/// here to reactively recompute the matched-zoom destination ID when
/// `savedConfigIDFromPicker` changes mid-dismiss.
private struct PickerSheet: View {

    let presenter: BackupConfigsPresenter
    let transitionNamespace: Namespace.ID?

    @Environment(\.dismiss) private var dismissSheet

    var body: some View {
        let zoomDestinationID: String = {
            if let saved = presenter.savedConfigIDFromPicker {
                return BackupConfigsRouter.editSourceID(for: saved)
            }
            return BackupConfigsRouter.pickerSourceID
        }()

        BackupConfigsAddRouter.buildView(onClose: handleClose)
            .presentationDetents([.large])
            .matchedZoomDestination(id: zoomDestinationID, in: transitionNamespace)
    }

    private func handleClose(_ configID: BackupConfig.ID?) {
        // Set BEFORE dismiss so SwiftUI re-evaluates `.matchedZoomDestination` with the
        // new row's source ID before the sheet starts animating away.
        if let configID {
            presenter.savedConfigIDFromPicker = configID
        }
        Task { @MainActor in
            dismissSheet()
        }
    }
}
