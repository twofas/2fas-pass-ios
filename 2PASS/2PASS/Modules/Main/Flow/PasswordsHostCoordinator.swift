// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CommonUI

/// Owns the single Passwords subtree (sidebar | list | detail) and reparents the *list* navigation
/// controller between the split's supplementary column and the tab bar's Passwords slot as the layout
/// swaps by width. Because the same list and detail instances are moved (never rebuilt), the open item
/// detail and any modal presented from the list or detail survive the swap with their live state.
///
/// Only the list nav moves. The sidebar (split primary) and the detail nav (split secondary) are
/// split-only and stay installed by `MainSplitFlowController`; the open detail itself is re-hosted
/// between the detail column and the list's nav stack by the subtree's coordinator.
final class PasswordsHostCoordinator {

    enum Host {
        case split
        case tab
    }

    /// The shared subtree. Implicitly-unwrapped so the `isDetailVisible` closure can capture `self`
    /// during init (two-phase init: `self` is only available once every stored property is initialized).
    private(set) var subtree: SharedItemsSubtree!

    private(set) var currentHost: Host?

    private weak var split: MainSplitViewController?
    private weak var tabBar: MainViewController?

    /// Occupies the Passwords tab slot (index 0) while the list nav is hosted by the split, so the
    /// Connect (1) / Settings (2) tab indices never shift. Carries the Passwords tab bar item so the
    /// slot still renders correctly if briefly visible.
    private let passwordsTabPlaceholder: UIViewController = {
        let placeholder = UIViewController()
        placeholder.tabBarItem = PasswordsNavigationFlowController.makePasswordsTabBarItem()
        return placeholder
    }()

    init(parent: PasswordsNavigationFlowControllerParent, filterState: PasswordsFilterState) {
        subtree = PasswordsNavigationFlowController.makeSharedItemsSubtree(
            parent: parent,
            isDetailVisible: { [weak self] in self?.isDetailColumnVisibleForActiveLayout ?? false },
            filterState: filterState
        )
    }

    /// The view controller seeding the Passwords tab slot at build time (swapped for the list nav on the
    /// first attach to the tab bar).
    var passwordsTabSlotPlaceholder: UIViewController { passwordsTabPlaceholder }

    func configure(split: MainSplitViewController, tabBar: MainViewController) {
        self.split = split
        self.tabBar = tabBar
    }

    /// Detail is shown as a column whenever the split is the active host; the tab bar pushes it onto
    /// the list nav instead. Drives `passwordsToItemDetail`'s routing. The split is pinned horizontally
    /// regular (see `MainSplitFlowController.start`), so it can never collapse — deliberately not read
    /// from `isCollapsed`, which still reports its initial `true` between the first attach and the
    /// split's first layout pass and would misroute the empty state and detail into the wrong column.
    var isDetailColumnVisibleForActiveLayout: Bool {
        switch currentHost {
        case .split: return true
        case .tab, .none: return false
        }
    }

    /// Removes the list nav from its current host without tearing it down (the subtree retains it).
    func detachFromCurrentHost() {
        switch currentHost {
        case .split:
            split?.setViewController(nil, for: .supplementary)
        case .tab:
            if let tabBar, var vcs = tabBar.viewControllers,
               vcs[safe: MainViewController.passwordsTabIndex] === subtree.listNavigationController {
                vcs[MainViewController.passwordsTabIndex] = passwordsTabPlaceholder
                tabBar.viewControllers = vcs
            }
        case .none:
            break
        }
        currentHost = nil
    }

    /// Installs the list nav into `host`. Sets `currentHost` first so `isDetailColumnVisibleForActiveLayout`
    /// (and therefore the detail re-host routing) reads the new value during `didReparent`.
    func attach(to host: Host) {
        currentHost = host
        switch host {
        case .split:
            split?.setViewController(subtree.listNavigationController, for: .supplementary)
        case .tab:
            if let tabBar, var vcs = tabBar.viewControllers,
               vcs[safe: MainViewController.passwordsTabIndex] === passwordsTabPlaceholder {
                vcs[MainViewController.passwordsTabIndex] = subtree.listNavigationController
                tabBar.viewControllers = vcs
            }
        }
    }

    /// Switches the list's layout mode, hands the search bar to the right owner, and re-hosts the open
    /// detail. Call after `attach(to:)` so the list's ancestor split resolves correctly for `applyLayout`.
    @MainActor
    func didReparent(to host: Host, sizeTransitionCoordinator: UIViewControllerTransitionCoordinator? = nil) {
        let coordinator = subtree.coordinator
        switch host {
        case .split:
            coordinator.applyListLayout(.splitColumn)
            coordinator.attachSearchToDetailColumn()
            coordinator.rehostDetail(forDetailColumnVisible: true, sizeTransitionCoordinator: sizeTransitionCoordinator)
        case .tab:
            coordinator.detachSearchFromDetailColumn()
            coordinator.applyListLayout(.standalone)
            coordinator.rehostDetail(forDetailColumnVisible: false, sizeTransitionCoordinator: nil)
        }
        // The empty-state placement (list column vs detail column) depends on the host, so it must be
        // re-evaluated even when the appearance callbacks that normally do it get coalesced away by
        // the same-layout-pass move.
        coordinator.reloadListAfterReparent()
    }

    /// Marks the shared list as reparenting so it ignores the spurious appearance callbacks the host
    /// swap fires (see `PasswordsNavigationFlowController.setReparenting`). Bracket the whole swap:
    /// `begin` before `detachFromCurrentHost`, `end` after `didReparent`.
    @MainActor
    func beginReparenting() {
        subtree.coordinator.setReparenting(true)
    }

    @MainActor
    func endReparenting() {
        subtree.coordinator.setReparenting(false)
    }
}
