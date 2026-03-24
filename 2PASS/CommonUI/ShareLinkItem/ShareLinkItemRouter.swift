// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ShareLinkItemRouter: Router {

    static func buildView(itemID: ItemID) -> some View {
        NavigationStack {
            ShareLinkItemView(
                presenter: .init(
                    itemID: itemID,
                    interactor: ModuleInteractorFactory.shared.shareLinkItemModuleInteractor()
                )
            )
        }
    }

    func routingType(for destination: ShareLinkItemDestination?) -> RoutingType? {
        switch destination {
        case .password, .share:
            return .sheet
        case .error(let message, _):
            return .alert(title: String(localized: .commonError), message: message)
        case nil:
            return nil
        }
    }

    @ViewBuilder
    func view(for destination: ShareLinkItemDestination) -> some View {
        switch destination {
        case .password(let initialPassword, let onSave, let onCancel):
            ShareLinkItemPasswordRouter.buildView(
                initialPassword: initialPassword,
                onSave: onSave,
                onCancel: onCancel
            )
        case .share(let title, let url, let onComplete):
            ShareSheetView(
                title: title,
                url: url,
                excludedActivityTypes: nil,
                activityComplete: onComplete,
                activityError: onComplete
            )
        case .error(_, let onDismiss):
            Button(.commonOk, action: onDismiss)
        }
    }
}
