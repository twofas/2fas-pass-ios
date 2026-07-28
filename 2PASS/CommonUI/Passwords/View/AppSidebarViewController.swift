// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

protocol PasswordsSidebarViewControlling: AnyObject {
    func reloadFilters()
    func reloadSelectedFilters()
}

/// Primary column of the iPad unified split. Hosts the SwiftUI `AppSidebarView`; the filter snapshot
/// lives in `AppSidebarModel`, refreshed from `PasswordsPresenter` on each `reloadFilters()`. Top-level
/// sections (Connect, Settings) are installed as footer items by the split coordinator.
public final class AppSidebarViewController: UIHostingController<AnyView> {

    private let model: AppSidebarModel

    /// Set when a counts reload arrives while the sidebar is off-window (tab layout — and always on
    /// iPhone, where the shared subtree builds a sidebar that never shows). `model.refresh()` runs a
    /// full-vault counts pass, so it's deferred until the sidebar is actually about to render
    /// instead of being paid on every reload it can't display.
    private var needsDeferredRefresh = false

    weak var presenter: PasswordsPresenter? {
        didSet {
            model.presenter = presenter
            reloadFilters()
        }
    }

    public init() {
        let model = AppSidebarModel()
        self.model = model
        super.init(rootView: AnyView(AppSidebarView(model: model)))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        setupNavigationBar()
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Flush a deferred counts refresh here rather than in the appearance callbacks: a reparent
        // can skip `viewWillAppear`, but anything coming on screen is guaranteed a layout pass.
        if needsDeferredRefresh {
            needsDeferredRefresh = false
            model.refresh()
        }
    }

    /// Sidebar navigation bar, overriding the opaque `mainBackground` bar the base
    /// `CommonNavigationController` applies. On iOS 26 it keeps a translucent default-blur bar (matching
    /// `PasswordsViewController.setupNavigationBar`) so content blurs under the glass bar as it scrolls.
    /// On iOS 18 the bar is fully transparent, letting the sidebar read as a single flat surface behind
    /// the gray footer buttons.
    private func setupNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        let appearance = UINavigationBarAppearance()
        if #available(iOS 26.0, *) {
            appearance.configureWithDefaultBackground()
        } else {
            appearance.configureWithTransparentBackground()
        }
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }

    /// Installs the bottom-pinned top-level sections (e.g. Connect/Settings). Kept generic so CommonUI
    /// needn't know about the app's sections.
    public func setFooterItems(_ items: [SidebarFooterItem]) {
        model.footerItems = items
    }

    /// Shows/hides the badge dot on a footer item (e.g. Settings sync errors).
    public func setFooterBadge(_ visible: Bool, forItemID id: String) {
        if visible {
            model.badgedFooterItemIDs.insert(id)
        } else {
            model.badgedFooterItemIDs.remove(id)
        }
    }
}

extension AppSidebarViewController: PasswordsSidebarViewControlling {

    public func reloadFilters() {
        guard viewIfLoaded?.window != nil else {
            needsDeferredRefresh = true
            return
        }
        needsDeferredRefresh = false
        model.refresh()
    }

    public func reloadSelectedFilters() {
        model.refreshSelection()
    }
}
