// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CommonUI

/// Root of the Main module that swaps its content by available width. At or above
/// `MainLayout.splitMinimumWidth` it shows the sidebar split (sidebar | list | detail); below it shows
/// the tab bar, which iPadOS renders as a floating top tab bar in the regular size class and iPhone
/// renders as the standard bottom tab bar. Owns the presenter, forwards lifecycle, and mirrors the
/// Settings badge onto both representations so it survives swaps.
final class MainContainerViewController: UIViewController {
    var presenter: MainPresenter!

    private var split: MainSplitViewController?
    private var tabBar: MainViewController?
    /// Retains the split's coordinator for the container's lifetime.
    private var splitCoordinator: MainSplitFlowController?
    /// Retains the shared Passwords subtree and reparents it between the split and tab bar on swap.
    private var passwordsHost: PasswordsHostCoordinator?
    /// Retains the shared Connect instance and reparents it between the tab slot and the split's
    /// modal presentation on swap.
    private var connectHost: ConnectHostCoordinator?

    private weak var activeChild: UIViewController?
    private var isBadgeVisible = false
    /// Guards `updateActiveChild` against re-entrancy from the layout passes it triggers while moving
    /// view controllers between hosts.
    private var isSwapping = false

    /// Whether the wide (split) layout is the active child; drives layout-dependent decisions made
    /// after async work (e.g. where to re-open the Connect scanner after an acceptance sheet).
    var isSplitLayoutActive: Bool { activeChild === split }

    func configure(
        split: MainSplitViewController,
        tabBar: MainViewController,
        splitCoordinator: MainSplitFlowController,
        passwordsHost: PasswordsHostCoordinator,
        connectHost: ConnectHostCoordinator
    ) {
        self.split = split
        self.tabBar = tabBar
        self.splitCoordinator = splitCoordinator
        self.passwordsHost = passwordsHost
        self.connectHost = connectHost
    }

    /// The in-flight size-transition coordinator. The swap itself stays width-driven in
    /// `viewWillLayoutSubviews` (which also covers the first layout), but work that must wait for the
    /// transition to unwind — like re-hosting the open detail, whose pop is only half-applied inside
    /// the rotation's animation block on iOS 18 — is scheduled on this coordinator's completion.
    /// Weak: UIKit releases the coordinator when the transition ends.
    private weak var sizeTransitionCoordinator: UIViewControllerTransitionCoordinator?

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        sizeTransitionCoordinator = coordinator
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateActiveChild()
    }

    /// Installs the split or the tab bar depending on the current width, swapping only when the choice
    /// changes so resizing doesn't churn the hierarchy every layout pass. The shared Passwords subtree
    /// (list + open detail + any modal they present) is reparented between the two — never rebuilt — so
    /// its live state survives the swap.
    private func updateActiveChild() {
        guard let split, let tabBar, let passwordsHost else { return }

        let desired: UIViewController =
            MainLayout.usesSplitLayout(atWidth: view.bounds.width) ? split : tabBar
        guard desired !== activeChild else { return }
        guard isSwapping == false else { return }
        isSwapping = true
        defer { isSwapping = false }

        let previous = activeChild

        // Bracket a real host swap (not the first install) so the shared list ignores the spurious
        // appearance callbacks the detach/attach fires — it moves between two on-screen columns and
        // never actually leaves the screen. Without this the spurious `viewWillDisappear` tears down
        // appearance-paired state that the missing `viewWillAppear` never restores (see
        // `PasswordsHostCoordinator.beginReparenting`).
        let isReparent = previous != nil
        if isReparent { passwordsHost.beginReparenting() }
        defer { if isReparent { passwordsHost.endReparenting() } }

        // A. Section-sheet carry-over (Connect/Settings only). `presentedSection` is non-nil *only* when
        // the split's current modal is the tracked section sheet — a modal presented from the shared
        // list/detail is not, so it is left untouched to ride along on the reparented subtree.
        if desired === tabBar, previous === split {
            let section = splitCoordinator?.presentedSection
            tabBar.select(section)
            if section != nil {
                split.presentedViewController?.dismiss(animated: false)
            }
        }

        // B. Detach the shared list nav and the shared Connect instance from their current hosts (both
        // stay alive — their coordinators retain them — so removing the old shell next doesn't tear
        // them down). For Connect this also drops an in-flight permissions push/sheet; if step A just
        // dismissed the split's Connect modal, this reclaims the instance from the dying container.
        passwordsHost.detachFromCurrentHost()
        connectHost?.detachFromCurrentHost()

        // C. Remove the old shell from the container.
        activeChild?.unplaceFromParent()

        // D. Install the new shell — it must be in the window before the subtree re-enters it, so a modal
        // presented from the detail re-enters a live window in the same pass and isn't torn down.
        placeChild(desired)
        activeChild = desired

        // E. Attach the shared list nav to the new host (sets the host's detail-visibility semantics),
        // and the shared Connect instance to its matching home (tab slot; for the split it parks until
        // presented). If step A selected the Connect tab, the live scanner lands in that selected slot.
        let host: PasswordsHostCoordinator.Host = (desired === split) ? .split : .tab
        passwordsHost.attach(to: host)
        connectHost?.attach(to: host)

        // F. Switch the list's layout mode, hand off the search bar, and re-host the open detail.
        passwordsHost.didReparent(to: host, sizeTransitionCoordinator: sizeTransitionCoordinator)

        // G. Mirror the section carry-over the other way: a selected Connect/Settings tab is re-presented
        // as a sheet over the split (Passwords maps to the split's base content, so nothing is presented).
        if desired === split, previous === tabBar, let section = tabBar.selectedSection {
            splitCoordinator?.present(section, animated: false)
        }
    }

    private func applyBadge() {
        for target in [split as MainViewControlling?, tabBar as MainViewControlling?] {
            if isBadgeVisible {
                target?.showBadge()
            } else {
                target?.hideBadge()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presenter.viewDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        presenter.viewWillDisappear()
    }
}

extension MainContainerViewController: MainViewControlling {
    func showBadge() {
        isBadgeVisible = true
        applyBadge()
    }

    func hideBadge() {
        isBadgeVisible = false
        applyBadge()
    }
}

/// The single source of truth for the Main screen's width-driven layout choice. At or above
/// `splitMinimumWidth` the Main screen shows the sidebar split (sidebar | list | detail); below it it
/// shows the tab bar.
///
/// This decision is deliberately **width-based, not size-class-based**. An 11" iPad in portrait (834pt)
/// reports a `.regular` horizontal size class yet is below the split threshold, so it shows the tab bar.
/// Anything whose presentation should track the split/tab layout — most notably sheet sizing, where the
/// split presents form/page sheets (default page size) and the tab bar presents iPhone-style bottom
/// sheets — must consult `usesSplitLayout(atWidth:)` rather than the size class, or it would diverge from
/// the actual layout in that in-between width range.
enum MainLayout {

    /// At or above this width the split shows all three columns (sidebar | list | detail); below it the
    /// tab bar is shown.
    ///
    /// Set to 1024pt — the portrait width of the 13" iPad — so that orientation is the narrowest layout
    /// that still gets the tiled sidebar (11" iPad portrait at 834pt and every narrower window fall to
    /// the tab bar). The split's column widths in `MainSplitFlowController` (`minimumSidebarWidth` 220 +
    /// the list's opening width `maximumListWidth` 320 + a usable detail) are deliberately tuned to tile
    /// three columns within this exact width; if they grow past it the split silently downgrades to two
    /// columns (`.oneBesideSecondary`) and hides the sidebar, so retune them together with this value.
    static let splitMinimumWidth: CGFloat = 1024

    /// Whether a container of the given width uses the split layout (vs. the tab bar). This is the signal
    /// that sheet presentation keys off — see the type doc for why it is width-based rather than
    /// size-class-based.
    static func usesSplitLayout(atWidth width: CGFloat) -> Bool {
        width >= splitMinimumWidth
    }
}
