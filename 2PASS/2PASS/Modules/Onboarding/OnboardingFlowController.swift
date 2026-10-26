// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

protocol OnboardingNavigationFlowControllerParent: AnyObject {
    func onboardingToLoggedIn()
}

final class OnboardingFlowController: NavigationFlowController {
    private weak var parent: OnboardingNavigationFlowControllerParent?

    static func embedAsRoot(
        in viewController: UIViewController,
        parent: OnboardingNavigationFlowControllerParent
    ) -> UIViewController {

        let flowController = OnboardingFlowController()
        flowController.parent = parent

        let navigation = MainActor.assumeIsolated {
            makeNavigationController(parent: parent)
        }
        flowController.navigationController = navigation

        viewController.placeChild(navigation)

        return navigation
    }

    // One stack for the pages, the steps and the recovery flow; every hosted screen is wrapped
    // with the shield's reporter and the flow's environment (spec 0048 D1, D4).
    @MainActor
    private static func makeNavigationController(parent: OnboardingNavigationFlowControllerParent) -> SlideNavigationController {
        let progress = OnboardingProgress()
        let dismissFlow = DismissFlowAction(action: { [weak parent] in
            parent?.onboardingToLoggedIn()
        })
        let navigation = SlideNavigationController(root: OnboardingPagesRouter.buildView()) { screen in
            AnyView(
                OnboardingProgressReporter(progress: progress, content: screen)
                    .environment(\.dismissFlow, dismissFlow)
                    .tint(.brand500)
            )
        }
        navigation.setOverlay(OnboardingProgressOverlayView(progress: progress))
        navigation.view.backgroundColor = UIColor(resource: .mainBackground)
        navigation.navigationBar.tintColor = UIColor(resource: .brand500)
        return navigation
    }
}
