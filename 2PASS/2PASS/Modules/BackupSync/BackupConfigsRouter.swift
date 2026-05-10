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

    static let pickerSourceID = "backupConfigs.add.picker"

    static func editSourceID(for configID: UUID) -> String {
        "backupConfigs.edit.\(configID)"
    }

    @MainActor @ViewBuilder
    private func pickerView(presenter: BackupConfigsPresenter) -> some View {
        let bindable = Bindable(presenter)
        let zoomDestinationID: String = {
            if let saved = presenter.savedConfigIDFromPicker {
                return Self.editSourceID(for: saved)
            }
            return Self.pickerSourceID
        }()

        zoomDestination(
            BackupConfigsAddView(
                canAddiCloud: presenter.canAddiCloud,
                onAddiCloud: { presenter.addiCloud() },
                savedConfigID: bindable.savedConfigIDFromPicker
            )
            .presentationDetents([.large]),
            destinationID: zoomDestinationID
        )
    }

    @ViewBuilder
    private func zoomable<V: View>(_ view: V, sourceID: String) -> some View {
        if #available(iOS 26.0, *), let transitionNamespace {
            view.navigationTransition(.zoom(sourceID: sourceID, in: transitionNamespace))
        } else {
            view
        }
    }

    @ViewBuilder
    private func zoomDestination<V: View>(_ view: V, destinationID: String) -> some View {
        if let transitionNamespace {
            view.matchedZoomDestination(id: destinationID, in: transitionNamespace)
        } else {
            view
        }
    }
}
