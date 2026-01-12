// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CommonUI
import SwiftUI

protocol ConnectNavigationFlowControllerParent: AnyObject {
}

final class ConnectNavigationFlowController: NavigationFlowController {
    private weak var parent: ConnectNavigationFlowControllerParent?
    private weak var tabBarController: UITabBarController?
    
    static func showAsTab(
        in viewController: UITabBarController,
        parent: ConnectNavigationFlowControllerParent
    ) {
        let view = ConnectRouter.buildView(onScannedQRCode: {
            viewController.selectedIndex = 0
        }, onScanAgain: {
            viewController.selectedIndex = 1
        })
        
        let connectViewController = UIHostingController(rootView: view)
        connectViewController.tabBarItem = UITabBarItem(
            title: String(localized: .bottomBarConnect),
            image: UIImage(systemName: "personalhotspot"),
            selectedImage: UIImage(systemName: "personalhotspot")
        )
        viewController.addTab(connectViewController)
    }
}
