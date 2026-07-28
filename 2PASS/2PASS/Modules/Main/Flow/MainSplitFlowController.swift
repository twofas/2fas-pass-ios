// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CommonUI
import Data
import SwiftUI

/// iPad coordinator that composes the wide-layout split (sidebar | list | detail). The sidebar list
/// holds the item filters; Connect and Settings are footer items that present their screens modally
/// over the split. The narrow-width tab bar is a separate root managed by `MainContainerViewController`.
final class MainSplitFlowController {

    private weak var split: MainSplitViewController?
    private weak var parent: MainFlowController?

    /// The split's filter sidebar (split primary). Held weakly to toggle its Settings badge; the
    /// `PasswordsHostCoordinator` owns the subtree it belongs to.
    private weak var sidebar: AppSidebarViewController?

    /// Tracks the modally-presented section sheet so the container can carry it onto the matching tab
    /// when the layout swaps to the narrow width. The view controller is weak so a swipe-dismiss clears
    /// it automatically; `presentedSectionKind` records which section it is.
    private weak var presentedSectionViewController: UIViewController?
    private var presentedSectionKind: MainSection?

    /// Supplies the single shared Connect instance for the split's modal presentation; also owns the
    /// scanned-connection acceptance flow. Weak — retained by `MainContainerViewController`.
    weak var connectHost: ConnectHostCoordinator?

    private enum FooterItemID {
        static let connect = "connect"
        static let settings = "settings"
    }

    /// Lower bound for the sidebar (primary) column so its filter rows and footer items stay legible.
    /// Kept narrow so the sidebar + list + a usable detail all tile within the split's activation
    /// width (1024pt, the 13" iPad portrait width); otherwise the split downgrades to two columns and
    /// hides the sidebar. 220 is the practical floor where the "Connect"/"Settings" footer rows still
    /// read cleanly — retune together with `MainLayout.splitMinimumWidth`.
    private static let minimumSidebarWidth: CGFloat = 220

    /// Drag bounds for the list (supplementary) column. In `.twoBesideSecondary` the split ignores
    /// `preferredSupplementaryColumnWidth`: the column sizes to its (wide) automatic width and is only
    /// reined in by the maximum, so the list opens at `maximumListWidth` and the user can drag it
    /// narrower down to `minimumListWidth` (it can't be dragged wider than the maximum). The maximum
    /// also stays below the items grid's two-column threshold (2 × 310pt), so the list always renders
    /// as a single column. `maximumListWidth` is kept low enough that `minimumSidebarWidth` + this max
    /// + a usable detail tile within the split's activation width (1024pt, the 13" iPad portrait
    /// width) — otherwise the split downgrades to two columns and hides the sidebar. With the sidebar
    /// at 220 this leaves ~484pt for the detail at 1024, enough for the split to keep all three
    /// columns tiled. Adjust to retune the default/widest width.
    private static let minimumListWidth: CGFloat = 260
    private static let maximumListWidth: CGFloat = 320

    init(split: MainSplitViewController, parent: MainFlowController) {
        self.split = split
        self.parent = parent
    }

    /// The section whose sheet is the split's active modal, or `nil` when none is presented (including
    /// after the user swipe-dismisses it), so the container can carry it onto the tab bar on resize.
    var presentedSection: MainSection? {
        guard let presentedSectionViewController,
              split?.presentedViewController === presentedSectionViewController else { return nil }
        return presentedSectionKind
    }

    /// Installs the split's fixed columns from the shared subtree: the filter sidebar (primary) and the
    /// detail column (secondary). The list column (supplementary) is installed by `PasswordsHostCoordinator`
    /// on attach, since it moves to the tab bar's Passwords slot in the narrow layout.
    func start(subtree: SharedItemsSubtree) {
        guard let split else { return }

        let sidebar = subtree.sidebar
        self.sidebar = sidebar
        installSectionButtons(on: sidebar)

        let sidebarNavigation = CommonNavigationController()
        sidebarNavigation.setViewControllers([sidebar], animated: false)

        split.setViewController(sidebarNavigation, for: .primary)
        split.setViewController(subtree.detailNavigationController, for: .secondary)
        split.preferredDisplayMode = .twoBesideSecondary
        split.preferredSplitBehavior = .tile
        split.traitOverrides.horizontalSizeClass = .regular
        split.minimumPrimaryColumnWidth = Self.minimumSidebarWidth
        split.minimumSupplementaryColumnWidth = Self.minimumListWidth
        split.maximumSupplementaryColumnWidth = Self.maximumListWidth
        // Keep the sidebar always visible: suppress the swipe gesture, which (with the
        // default `.automatic` display-mode-button visibility) also hides the toggle button.
        split.presentsWithGesture = false

        split.onSetBadge = { [weak self] visible in
            self?.sidebar?.setFooterBadge(visible, forItemID: FooterItemID.settings)
        }
    }

    // MARK: - Top-level sections (Connect / Settings)

    /// Supplies Connect and Settings as sidebar footer items; the SwiftUI sidebar renders them and the
    /// Settings badge dot. The actions present their screens modally over the split.
    private func installSectionButtons(on sidebar: AppSidebarViewController) {
        sidebar.setFooterItems([
            SidebarFooterItem(
                id: FooterItemID.connect,
                title: String(localized: .bottomBarConnect),
                systemImage: "personalhotspot",
                action: { [weak self] in self?.present(.connect) }
            ),
            SidebarFooterItem(
                id: FooterItemID.settings,
                title: String(localized: .commonSettings),
                systemImage: "gear",
                isIconOnly: true,
                action: { [weak self] in self?.present(.settings) }
            )
        ])
    }

    // MARK: - Modal presentation

    /// Presents `section` as a sheet over the split. Callable by the container to carry the tab bar's
    /// selected tab onto the split when the layout swaps to the wide width; no-op if the split already
    /// presents a modal.
    func present(_ section: MainSection, animated: Bool = true) {
        guard let split, let parent, split.presentedViewController == nil else { return }

        let sectionViewController: UIViewController
        switch section {
        case .connect:
            guard let connectHost else { return }
            // The shared Connect instance (reparented out of the tab slot or its parked state) inside
            // a disposable modal container; the coordinator owns the close and scanned-session wiring.
            sectionViewController = connectHost.beginSplitModalPresentation()
        case .settings:
            let settings = SettingsNavigationFlowController.makeRootViewController(
                parent: parent,
                onClose: { [weak split] in split?.dismiss(animated: true) }
            )
            // `.formSheet` (not `.pageSheet`) so the sheet honors `preferredContentSize` for its width on
            // iPad — `.pageSheet` pins to a system width and ignores it. The width sizes the two-column
            // Settings split inside (360pt sidebar + detail); the system clamps both dimensions to the
            // container, so an over-large value just means "as wide/tall as allowed".
            settings.modalPresentationStyle = .formSheet
            settings.preferredContentSize = CGSize(width: 900, height: 1000)
            sectionViewController = settings
        }

        presentedSectionViewController = sectionViewController
        presentedSectionKind = section
        split.present(sectionViewController, animated: animated)
    }
}
