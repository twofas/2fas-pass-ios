// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct SetupVaultRouter: Router {

    @ViewBuilder
    static func buildView() -> some View {
        SetupVaultView(presenter: SetupVaultPresenter())
    }
    
    func routingType(for destination: SetupVaultRouteDestination?) -> RoutingType? {
        switch destination {
        case .generateSecretKey:
            return .slidePush
        case .none:
            return nil
        }
    }
    
    @ViewBuilder
    func view(for destination: SetupVaultRouteDestination) -> some View {
        switch destination {
        case .generateSecretKey:
            GenerateSecretKeyRouter.buildView()
        }
    }
}
