// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CommonUI
import Data
import SwiftUI

protocol ConnectNavigationFlowControllerParent: AnyObject {
}

final class ConnectNavigationFlowController: NavigationFlowController {
    private weak var parent: ConnectNavigationFlowControllerParent?

    /// Builds the single shared Connect view controller (one hosting controller, one presenter chain,
    /// one camera session) that the host coordinator reparents between the tab bar's Connect slot and
    /// a modal over the iPad split. Per-layout behavior is switched at runtime via
    /// `ConnectPresenter.apply(isModalPresentation:)`, not baked in here.
    static func makeShared(
        parent: ConnectNavigationFlowControllerParent,
        onClose: @escaping Callback,
        onScannedSession: @escaping (ConnectSession) -> Void
    ) -> (viewController: UIViewController, presenter: ConnectPresenter) {
        let build = ConnectRouter.buildView(onClose: onClose, onScannedSession: onScannedSession)
        let viewController = UIHostingController(rootView: build.view)
        viewController.tabBarItem = makeConnectTabBarItem()
        return (viewController, build.presenter)
    }

    static func makeConnectTabBarItem() -> UITabBarItem {
        UITabBarItem(
            title: String(localized: .bottomBarConnect),
            image: UIImage(systemName: "personalhotspot"),
            selectedImage: UIImage(systemName: "personalhotspot")
        )
    }
}
