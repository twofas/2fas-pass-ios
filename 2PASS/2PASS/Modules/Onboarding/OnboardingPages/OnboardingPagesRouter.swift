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
    static func buildView(onLogin: @escaping Callback) -> some View {
        NavigationStack {
            OnboardingPagesView(presenter: OnboardingPagesPresenter())
        }
        .environment(\.dismissFlow, DismissFlowAction(action: onLogin))
        .tint(.brand500)
    }
    
    func routingType(for destination: OnboardingPagesDestination?) -> RoutingType? {
        switch destination {
        case .getStarted?:
            return .push
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
            OnboardingStepsStack {
                SetupVaultRouter.buildView()
            }
        case .recover:
            VaultRecoveryRouter.buildView()
        }
    }
}
