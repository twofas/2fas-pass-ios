// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct HalfwayRouter: Router {

    @ViewBuilder
    static func buildView() -> some View {
        HalfwayView(presenter: HalfwayPresenter())
    }
    
    func routingType(for destination: HalfwayRouteDestination?) -> RoutingType? {
        switch destination {
        case .createMasterPassword:
            return .slidePush
        case .none:
            return nil
        }
    }
    
    @ViewBuilder
    func view(for destination: HalfwayRouteDestination) -> some View {
        switch destination {
        case .createMasterPassword:
            MasterPasswordRouter.buildView(kind: .onboarding, onFinish: {}, onClose: {})
        }
    }
}
