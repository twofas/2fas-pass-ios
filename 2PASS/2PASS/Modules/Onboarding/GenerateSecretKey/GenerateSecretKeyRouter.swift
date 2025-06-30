// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct GenerateSecretKeyRouter: Router {

    @ViewBuilder
    static func buildView() -> some View {
        GenerateSecretKeyView(presenter: GenerateSecretKeyPresenter(interactor: ModuleInteractorFactory.shared.generateSecretKeyModuleInteractor()))
    }
    
    func routingType(for destination: GenerateSecretKeyRouteDestination?) -> RoutingType? {
        switch destination {
        case .halfway:
            return .slidePush
        case .none:
            return nil
        }
    }
    
    @ViewBuilder
    func view(for destination: GenerateSecretKeyRouteDestination) -> some View {
        switch destination {
        case .halfway:
            HalfwayRouter.buildView()
        }
    }
}
