// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

protocol MainViewControlling: AnyObject {
    func showBadge()
    func hideBadge()
}

final class MainViewController: UITabBarController {
    var presenter: MainPresenter!
    
    private let badgeIndex: Int = 2
    private let badge = "1"
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        changeStyling()
        
        registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]
        ) { (self: Self, previousTraitCollection: UITraitCollection) in
            if self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle {
                self.changeStyling()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presenter.viewDidAppear()
    }
    
    private func changeStyling() {
        let app = tabBar.standardAppearance.copy()
        app.backgroundColor = Asset.mainBackgroundColor.color
        app.shadowColor = Asset.dividerColor.color
        app.shadowImage = Asset.shadowLine.image
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .tile)
        
        let tabBarItemFont = UIFont.preferredFont(forTextStyle: .caption2)
        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.normal.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: Asset.inactiveColor.color,
            NSAttributedString.Key.font: tabBarItemFont
        ]
        tabBarItemAppearance.selected.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: Asset.accentColor.color,
            NSAttributedString.Key.font: tabBarItemFont
        ]
        tabBarItemAppearance.focused.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: Asset.accentColor.color,
            NSAttributedString.Key.font: tabBarItemFont
        ]
        
        app.compactInlineLayoutAppearance = tabBarItemAppearance
        app.inlineLayoutAppearance = tabBarItemAppearance
        app.stackedLayoutAppearance = tabBarItemAppearance
        
        tabBar.standardAppearance = app
        tabBar.scrollEdgeAppearance = app
    }
    
    override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            viewControllers?.forEach({ vc in
                vc.willMove(toParent: nil)
            })
        }
        
        super.willMove(toParent: parent)
    }
}

extension MainViewController: MainViewControlling {
    func showBadge() {
        viewControllers?[safe: badgeIndex]?.tabBarItem.badgeValue = badge
    }
    
    func hideBadge() {
        viewControllers?[safe: badgeIndex]?.tabBarItem.badgeValue = nil
    }
}
