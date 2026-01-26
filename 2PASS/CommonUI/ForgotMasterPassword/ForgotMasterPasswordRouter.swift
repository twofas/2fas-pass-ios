// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ForgotMasterPasswordRouter: Router {

    static func buildView() -> some View {
        NavigationStack {
            ForgotMasterPasswordView(
                presenter: .init(interactor: ModuleInteractorFactory.shared.forgotMasterPasswordModuleInteractor())
            )
        }
    }

    func view(for destination: ForgotMasterPasswordDestination) -> some View {
        switch destination {
        case .placeholder:
            return EmptyView()
        }
    }

    func routingType(for destination: ForgotMasterPasswordDestination?) -> RoutingType? {
        switch destination {
        case .placeholder:
            return .push
        case nil:
            return nil
        }
    }
}
