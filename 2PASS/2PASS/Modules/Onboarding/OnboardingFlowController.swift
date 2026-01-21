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

        let view = OnboardingPagesRouter.buildView(onLogin: { [weak parent] in
            parent?.onboardingToLoggedIn()
        })
        
        let vc = UIHostingController(rootView: view)
        vc.view.backgroundColor = UIColor(resource: .mainBackground)
        vc.navigationController?.navigationItem.backButtonDisplayMode = .minimal
                
        viewController.placeChild(vc)
        
        return vc
    }
}
