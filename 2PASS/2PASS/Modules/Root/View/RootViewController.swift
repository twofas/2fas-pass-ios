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
        view.backgroundColor = Asset.mainBackgroundColor.color
        applyAppearance()
    }
    
    override var shouldAutorotate: Bool { UIDevice.isiPad }
    
    private func applyAppearance() {
        let bgImage = Asset.barsBackground.image
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        let shadowLine = Asset.shadowLine.image
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .tile)

        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = Asset.accentColor.color
        
        let tabBarAppearance = UITabBar.appearance()
        tabBarAppearance.backgroundColor = Asset.mainBackgroundColor.color
        tabBarAppearance.tintColor = Asset.accentColor.color
        tabBarAppearance.unselectedItemTintColor = Asset.inactiveColor.color
        tabBarAppearance.shadowImage = shadowLine
        tabBarAppearance.backgroundImage = bgImage
        tabBarAppearance.isTranslucent = true
        
        UIPageControl.appearance().currentPageIndicatorTintColor = .neutral950
        UIPageControl.appearance().pageIndicatorTintColor = .neutral200
    }
}
