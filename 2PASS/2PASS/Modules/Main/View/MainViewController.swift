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

/// A top-level Main destination that exists both as a tab (narrow layout) and as a modal section over
/// the split (wide layout). Passwords is the split's base content, so it has no section — the absence
/// of a section (`nil`) maps to the Passwords tab.
enum MainSection {
    case connect
    case settings
}

final class MainViewController: UITabBarController {
    /// Optional because this tab bar also serves as the split view's `.compact` column, where the
    /// split (not the tab bar) owns the presenter and forwards lifecycle. Only set it when the tab
    /// bar is itself the presenter-driven root.
    var presenter: MainPresenter?
    
    /// Single owner of the section → tab slot mapping. The host coordinators swap their placeholder
    /// and real controllers by these indices, so a tab reorder only ever happens here.
    static let passwordsTabIndex: Int = 0
    static let connectTabIndex: Int = 1
    static let settingsTabIndex: Int = 2
    private let badge = "1"

    /// Selects the tab matching `section`; `nil` selects the Passwords tab (the split's base content).
    func select(_ section: MainSection?) {
        switch section {
        case .none: selectedIndex = Self.passwordsTabIndex
        case .connect: selectedIndex = Self.connectTabIndex
        case .settings: selectedIndex = Self.settingsTabIndex
        }
    }

    /// The section the selected tab maps to, or `nil` when the Passwords tab is selected.
    var selectedSection: MainSection? {
        switch selectedIndex {
        case Self.connectTabIndex: return .connect
        case Self.settingsTabIndex: return .settings
        default: return nil
        }
    }
    
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
        presenter?.viewDidAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter?.viewWillDisappear()
    }
    
    private func changeStyling() {
        let app = tabBar.standardAppearance.copy()
        app.backgroundColor = UIColor(resource: .mainBackground)
        app.shadowColor = UIColor(resource: .divider)
        app.shadowImage = UIImage(resource: .shadowLine)
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .tile)
        
        let tabBarItemFont = UIFont.preferredFont(forTextStyle: .caption2)
        let tabBarItemAppearance = UITabBarItemAppearance()
        tabBarItemAppearance.normal.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(resource: .inactive),
            NSAttributedString.Key.font: tabBarItemFont
        ]
        tabBarItemAppearance.selected.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(resource: .accent),
            NSAttributedString.Key.font: tabBarItemFont
        ]
        tabBarItemAppearance.focused.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(resource: .accent),
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
        viewControllers?[safe: Self.settingsTabIndex]?.tabBarItem.badgeValue = badge
    }

    func hideBadge() {
        viewControllers?[safe: Self.settingsTabIndex]?.tabBarItem.badgeValue = nil
    }
}
