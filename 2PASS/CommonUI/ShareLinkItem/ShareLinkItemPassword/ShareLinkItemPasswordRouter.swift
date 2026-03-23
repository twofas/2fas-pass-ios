// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ShareLinkItemPasswordRouter: Router {

    static func buildView(
        initialPassword: String,
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        ShareLinkItemPasswordView(
            presenter: ShareLinkItemPasswordPresenter(
                initialPassword: initialPassword,
                interactor: ModuleInteractorFactory.shared.shareLinkItemPasswordModuleInteractor()
            ),
            onSave: onSave,
            onCancel: onCancel
        )
    }

    func routingType(for destination: ShareLinkItemPasswordDestination?) -> RoutingType? {
        switch destination {
        case .passwordGenerator:
            return .sheet
        case nil:
            return nil
        }
    }

    @ViewBuilder
    func view(for destination: ShareLinkItemPasswordDestination) -> some View {
        switch destination {
        case .passwordGenerator(let onUse, let onClose):
            PasswordGeneratorRouter.buildView(
                close: onClose,
                closeUsePassword: onUse
            )
        }
    }
}
