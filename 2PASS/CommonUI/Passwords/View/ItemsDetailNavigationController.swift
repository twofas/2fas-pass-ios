// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

/// Detail (secondary) column navigation controller for the iPad items split. It hosts the items
/// search bar in its own nav bar — i.e. on the far right of the screen — and re-attaches it to
/// whatever view controller becomes its top, so the bar persists as the detail content swaps
/// (placeholder ↔ item detail).
final class ItemsDetailNavigationController: CommonNavigationController {

    var itemsSearchController: UISearchController? {
        didSet {
            if oldValue !== itemsSearchController, let oldValue {
                detach(oldValue)
            }
            attachSearch()
        }
    }

    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        attachSearch()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        attachSearch()
    }

    private func attachSearch() {
        // The detail column only ever hosts the search bar on iOS 26+ — before that the list column
        // keeps its own bar and `itemsSearchController` is never set, so this method no-ops there.
        guard let itemsSearchController, let top = topViewController else { return }
        top.navigationItem.searchController = itemsSearchController
        top.navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 26.0, *) {
            top.navigationItem.preferredSearchBarPlacement = .integrated
        }
    }

    /// Removes a previously-attached search controller from the current top view controller so the
    /// search bar doesn't linger when ownership moves elsewhere (e.g. to the list's own nav item when
    /// the layout leaves the split).
    private func detach(_ controller: UISearchController) {
        if topViewController?.navigationItem.searchController === controller {
            topViewController?.navigationItem.searchController = nil
        }
    }
}
