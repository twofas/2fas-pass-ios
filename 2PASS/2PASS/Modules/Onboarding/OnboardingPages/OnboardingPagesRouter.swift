// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct OnboardingPagesRouter: Router {
    
    @ViewBuilder
    static func buildView() -> some View {
        OnboardingPagesView(presenter: OnboardingPagesPresenter())
    }
    
    func routingType(for destination: OnboardingPagesDestination?) -> RoutingType? {
        switch destination {
        case .getStarted?:
            return .slidePush
        case .recover?:
            return .push
        case .none:
            return nil
        }
    }
    
    @ViewBuilder
    func view(for destination: OnboardingPagesDestination) -> some View {
        switch destination {
        case .getStarted:
            SetupVaultRouter.buildView()
        case .recover:
            VaultRecoveryRouter.buildView()
        }
    }
}
