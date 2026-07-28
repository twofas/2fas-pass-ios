// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

/// Persistent root of the iPad items split's detail column. It hosts the actual detail content
/// (placeholder or item detail) as a swappable child while keeping the navigation item — and crucially
/// its search bar — attached to a single, never-replaced view controller. The child's title and
/// bar button items are forwarded up so the item detail's Edit/Share actions still appear.
final class ItemsDetailContainerViewController: UIViewController {

    private var content: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = UIColor(resource: .mainBackground)
    }

    func setContent(_ viewController: UIViewController) {
        takeContent()

        content = viewController
        placeChild(viewController)
        viewController.view.layoutIfNeeded()
        syncNavigationItem(from: viewController)
    }

    /// Detaches the current detail child and hands it back without destroying it, so a still-alive
    /// view controller (e.g. one presenting a modal) can be re-hosted in another column or pushed on
    /// a navigation stack when the layout swaps. Returns `nil` when nothing is hosted.
    @discardableResult
    func takeContent() -> UIViewController? {
        guard let content else { return nil }
        content.willMove(toParent: nil)
        content.view.removeFromSuperview()
        content.removeFromParent()
        self.content = nil
        return content
    }

    /// Mirrors the child's title and bar button items onto the container, leaving `searchController`
    /// (owned by the detail navigation controller) untouched so its text persists across swaps.
    private func syncNavigationItem(from child: UIViewController) {
        navigationItem.title = child.navigationItem.title ?? child.title
        navigationItem.leftBarButtonItems = child.navigationItem.leftBarButtonItems
        navigationItem.rightBarButtonItems = child.navigationItem.rightBarButtonItems
    }
}
