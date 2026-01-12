// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

final class RootViewController: UIViewController {
    var presenter: RootPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(resource: .mainBackground)
        applyAppearance()
    }
    
    override var shouldAutorotate: Bool { UIDevice.isiPad }
    
    private func applyAppearance() {
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(resource: .accent)
        
        let tabBarAppearance = UITabBar.appearance()
        tabBarAppearance.tintColor = UIColor(resource: .accent)
        tabBarAppearance.unselectedItemTintColor = UIColor(resource: .inactive)
        
        UIPageControl.appearance().currentPageIndicatorTintColor = .neutral950
        UIPageControl.appearance().pageIndicatorTintColor = .neutral200
    }
}
