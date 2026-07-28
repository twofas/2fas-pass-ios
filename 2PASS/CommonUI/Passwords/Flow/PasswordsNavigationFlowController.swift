// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol PasswordsNavigationFlowControllerParent: AnyObject {
    func toQuickSetup()
    func toPremiumPlanPrompt(itemsLimit: Int)
}

/// A single items subtree (filter sidebar, list nav, detail nav) plus the coordinator that drives it,
/// for an app root that reparents the same subtree between the iPad split and the tab bar (rather than
/// building one per layout). The sidebar is the split primary, the detail nav the split secondary; the
/// list nav moves between the split's supplementary column and the tab bar's Passwords slot.
public struct SharedItemsSubtree {
    public let sidebar: AppSidebarViewController
    public let listNavigationController: UINavigationController
    public let detailNavigationController: UINavigationController
    public let coordinator: PasswordsNavigationFlowController
}

public final class PasswordsNavigationFlowController: NavigationFlowController {
    private weak var parent: PasswordsNavigationFlowControllerParent?

    private weak var detailContainer: ItemsDetailContainerViewController?
    /// The multiselect count detail, kept so its count updates in place across selection changes.
    /// Weak: swapping the detail content (placeholder, item detail, empty vault) drops it automatically.
    private weak var multiselectDetail: ItemDetailMultiselectViewController?
    private var isDetailVisibleProvider: (() -> Bool)?
    /// The split's detail-column search controller (nil for the tab bar, where the list owns its own
    /// search bar). Held so a phrase set in the other layout can be restored into it.
    private weak var itemsSearchController: CommonSearchController?
    /// The detail (secondary) column nav controller, held so the search bar can be moved on/off it and
    /// the open detail re-hosted when the shared subtree is reparented between the split and tab bar.
    private weak var detailNavigation: ItemsDetailNavigationController?
    /// The currently-open item detail, tracked across both hosting styles (split column vs pushed on the
    /// list nav) so it — and any modal it presents — can be moved intact when the layout swaps.
    private weak var openDetailViewController: ItemDetailViewController?

    /// Builds a single items subtree (sidebar + list nav + detail nav) plus the coordinator that owns
    /// it, for an app root that reparents the same subtree between the iPad split and the tab bar.
    /// Exposes the coordinator so the host can drive layout-mode switches, search-bar handoff, and
    /// detail re-hosting on swap.
    public static func makeSharedItemsSubtree(
        parent: PasswordsNavigationFlowControllerParent,
        isDetailVisible: @escaping () -> Bool,
        filterState: PasswordsFilterState = PasswordsFilterState()
    ) -> SharedItemsSubtree {
        let build = makeItemsFlow(parent: parent, filterState: filterState)
        build.flowController.isDetailVisibleProvider = isDetailVisible
        // The list nav doubles as the tab bar's Passwords tab content when reparented there, so it
        // carries the Passwords tab bar item.
        build.listNavigation.tabBarItem = makePasswordsTabBarItem()

        let sidebar = AppSidebarViewController()
        sidebar.presenter = build.flowController.listViewController?.presenter
        build.flowController.listViewController?.presenter.sidebar = sidebar

        return SharedItemsSubtree(
            sidebar: sidebar,
            listNavigationController: build.listNavigation,
            detailNavigationController: build.detailNavigation,
            coordinator: build.flowController
        )
    }

    // MARK: - Shared construction

    /// Builds the flow controller plus the list and detail navigation controllers shared by the
    /// three-column root split and the two-column tab split. The caller wires `isDetailVisibleProvider`
    /// and any sidebar.
    private static func makeItemsFlow(
        parent: PasswordsNavigationFlowControllerParent,
        filterState: PasswordsFilterState
    ) -> (flowController: PasswordsNavigationFlowController, listNavigation: UINavigationController, detailNavigation: UINavigationController) {
        let flowController = PasswordsNavigationFlowController()
        flowController.parent = parent

        let listNavigation = CommonNavigationControllerFlow(flowController: flowController)
        flowController.navigationController = listNavigation

        PasswordsFlowController.setAsRoot(
            on: listNavigation,
            parent: flowController,
            filterState: filterState,
            layout: .splitColumn
        )

        let detailNavigation = ItemsDetailNavigationController()
        flowController.detailNavigation = detailNavigation
        // On iOS 26+ the items search lives in the detail column's nav bar (far right of the screen)
        // but filters the list. Reuse the list's own search controller (a single instance) so the typed
        // phrase and cursor survive when ownership moves to the list's nav item in the tab bar layout.
        // Before iOS 26 the list column keeps its own search bar (wired in its own view load), so the
        // detail column gets none.
        if PasswordsListLayout.splitHostsSearchInDetailColumn {
            let searchController = flowController.listViewController?.ownSearchController ?? CommonSearchController()
            searchController.searchBarDelegate = flowController.listViewController
            detailNavigation.itemsSearchController = searchController
            flowController.itemsSearchController = searchController
        }

        // A persistent container is the detail column's only root, so the search bar (attached to it)
        // survives detail content swaps; the content is hosted as a swappable child.
        let detailContainer = ItemsDetailContainerViewController()
        detailContainer.setContent(ItemDetailPlaceholderViewController())
        detailNavigation.setViewControllers([detailContainer], animated: false)
        flowController.detailContainer = detailContainer

        return (flowController, listNavigation, detailNavigation)
    }

    public static func makePasswordsTabBarItem() -> UITabBarItem {
        UITabBarItem(
            title: String(localized: .commonPasswords),
            image: UIImage(systemName: "lock.rectangle.stack"),
            selectedImage: UIImage(systemName: "lock.rectangle.stack")
        )
    }
}

extension PasswordsNavigationFlowController: PasswordsFlowControllerParent {

    public var isDetailColumnVisible: Bool {
        isDetailVisibleProvider?() ?? false
    }

    public var openDetailItemID: ItemID? {
        openDetailViewController?.presenter.itemID
    }

    public func passwordsToItemDetail(itemID: ItemID) {
        if isDetailColumnVisible, let detailContainer {
            let detail = ItemDetailFlowController.makeDetailViewController(parent: self, itemID: itemID)
            openDetailViewController = detail
            detailContainer.setContent(detail)
        } else {
            openDetailViewController = ItemDetailFlowController.push(
                on: navigationController,
                parent: self,
                itemID: itemID
            )
        }
    }

    public func selectItem(id: ItemID, contentType: ItemContentType) {
        passwordsToItemDetail(itemID: id)
    }

    public func clearDetailSelection() {
        guard isDetailColumnVisible, let detailContainer else { return }
        detailContainer.setContent(ItemDetailPlaceholderViewController())
    }

    public func showMultiselectDetail(selectedCount: Int) {
        guard isDetailColumnVisible, let detailContainer else { return }

        // Keep the same detail view controller across selection changes so the count updates in place
        // instead of swapping the whole child on every tap.
        if let multiselectDetail {
            multiselectDetail.update(selectedCount: selectedCount)
        } else {
            let multiselectDetail = ItemDetailMultiselectViewController(selectedCount: selectedCount)
            self.multiselectDetail = multiselectDetail
            detailContainer.setContent(multiselectDetail)
        }
    }

    public func restoreItemsSearchPhrase(_ phrase: String?) {
        // Called twice per list appearance (viewWillAppear and viewDidAppear); skip the redundant
        // set — and its UISearchBar layout invalidation — when the bar already holds the phrase.
        let text = phrase ?? ""
        guard let searchBar = itemsSearchController?.searchBar, searchBar.text != text else { return }
        searchBar.text = text
    }

    public func showEmptyVaultDetail() {
        guard isDetailColumnVisible, let detailContainer else { return }
        detailContainer.setContent(
            ItemDetailEmptyVaultViewController(onQuickSetup: { [weak self] in
                self?.toQuickSetup()
            })
        )
    }

    public func toQuickSetup() {
        parent?.toQuickSetup()
    }

    public func toPremiumPlanPrompt(itemsLimit: Int) {
        parent?.toPremiumPlanPrompt(itemsLimit: itemsLimit)
    }

    public func cancel() {
    }
}

extension PasswordsNavigationFlowController: ItemDetailFlowControllerParent {
    func itemDetailToEdit(_ itemID: ItemID) {
        // The coordinator (not the ephemeral detail) presents the editor and is its parent, so it
        // survives the detail being re-created on a split→tab swap. It's presented from the same swap
        // survivor as the detail's other modals, so it rides along and stays dismissable.
        ItemEditorNavigationFlowController.present(
            on: itemDetailModalPresenter(),
            parent: self,
            editItemID: itemID
        )
    }

    func itemDetailModalPresenter() -> UIViewController {
        // The list nav survives a split↔tab swap (it's reparented alive); the detail column is discarded
        // on split→tab, so the detail's self-dismissing modals must ride the list nav instead. The nav
        // itself, not its root list view controller: with a detail pushed on top, the list's view is
        // detached from the window, and UIKit warns about presenting from a detached controller.
        navigationController
    }

    func itemDetailClose() {
        if isDetailColumnVisible {
            clearDetailSelection()
        } else {
            navigationController.popToRootViewController(animated: true)
        }
    }

    func itemDetailAutoFillTextToInsert(_ text: String) {}
}

extension PasswordsNavigationFlowController: ItemEditorNavigationFlowControllerParent {
    func closeItemEditor(with result: SaveItemResult) {
        // Dismiss on the same survivor the editor was presented from, so it closes regardless of a
        // split↔tab swap having re-created the detail in the meantime.
        itemDetailModalPresenter().dismiss(animated: true)
    }
}

// MARK: - Shared subtree reparenting

public extension PasswordsNavigationFlowController {

    /// Switches the list between its standalone and split-column presentations after a reparent.
    func applyListLayout(_ layout: PasswordsListLayout) {
        listViewController?.applyLayout(layout)
    }

    /// Split mode: the detail column hosts the list's (single) search controller. iOS 26+ only —
    /// before that the list column keeps its own search bar, so the reparent must not move it off.
    func attachSearchToDetailColumn() {
        guard PasswordsListLayout.splitHostsSearchInDetailColumn else { return }
        guard let searchController = listViewController?.ownSearchController else { return }
        itemsSearchController = searchController
        detailNavigation?.itemsSearchController = searchController
    }

    /// Tab mode: the detail column releases the search controller so the list can reclaim it on its own
    /// nav item (handled by `applyLayout(.standalone)`).
    func detachSearchFromDetailColumn() {
        detailNavigation?.itemsSearchController = nil
        itemsSearchController = nil
    }

    /// Recomputes the list's empty-state placement after a reparent: the split keeps the list column
    /// blank and shows the empty screen in the detail column, the tab bar shows it on the list itself.
    /// That choice is made inside the presenter's reload, which normally runs on `viewWillAppear` — but
    /// a reparent moves the list between hosts within a single layout pass, where UIKit can coalesce
    /// the disappear/appear pair and skip the callback, so the swap drives the reload explicitly.
    @MainActor
    func reloadListAfterReparent() {
        listViewController?.presenter.reloadAfterReparent()
    }

    /// Brackets a host swap so the shared list ignores the appearance churn it produces. Detaching the
    /// list from its old host fires `viewWillDisappear` (and skips the matching `viewWillAppear`) even
    /// though the list only moves between two on-screen columns and never actually leaves the screen.
    /// Left unguarded that spurious disappear tears down appearance-paired state — the vault-change
    /// observer, keyboard inset tracking — that no later appear restores, so the list goes deaf to data
    /// changes after the swap (e.g. a Settings "remove all" no longer refreshes it). Set `true` before
    /// the detach and `false` after the attach; the controlled reload is driven by `reloadListAfterReparent`.
    @MainActor
    func setReparenting(_ isReparenting: Bool) {
        listViewController?.isReparenting = isReparenting
    }

    /// Settles the open detail after a reparent, in both directions.
    ///
    /// - tab → split: lift the *same* open detail off the list nav stack into the split's stable detail
    ///   column (a pop cleanly releases the list nav's scroll observation, so the move is safe).
    /// - split → tab: the detail column goes off-window, so re-open the item as a **fresh** detail pushed
    ///   onto the list nav (and clear the column) rather than moving the existing instance. A `UIScrollView`
    ///   supports only one navigation-controller scroll observer; moving the detail's SwiftUI
    ///   `HostingScrollView` from the detail nav to the list nav is unsupported and corrupts its layout
    ///   (and shared bar-button items across two live nav bars spin an iOS 18 Observation loop). A fresh
    ///   push is the same proven path the tab bar uses to open any item.
    ///
    /// Call after the subtree has been attached to its new host. When the tab → split swap runs
    /// inside a size transition (rotation), pass its coordinator: it flags that an iOS 18 pop
    /// lifting the detail off the list nav may still be half-applied, so the move detaches the
    /// detail manually (`settleDetailIntoColumn`) instead of waiting for the nav to finalize. The
    /// split → tab direction performs no pop — its fresh push runs synchronously and needs no
    /// coordinator.
    func rehostDetail(forDetailColumnVisible visible: Bool, sizeTransitionCoordinator: UIViewControllerTransitionCoordinator? = nil) {
        guard visible, let detailContainer else {
            // split → tab: re-open whatever item was showing in the (now off-window) detail column as a
            // fresh detail on the list nav, so the user keeps seeing it in the tab layout.
            // Not during multiselect — its single-selection preview reaches here through the same
            // `passwordsToItemDetail` path as a real open detail, but pushing it would land a detail
            // over a list still in editing mode, a state the tab layout can't reach on its own. Left
            // parked in the column, `updateMultiselectDetail` refreshes it on the next swap to split.
            if let openItemID = openDetailViewController?.presenter.itemID,
               listViewController?.presenter.isSelecting != true {
                reopenDetailInListNav(itemID: openItemID)
            }
            return
        }
        // Only when the detail is currently on the list nav stack (the user opened it in the tab bar);
        // otherwise it already lives in the detail column and needs no move.
        guard let detail = openDetailViewController,
              navigationController.topViewController === detail else { return }
        navigationController.popViewController(animated: false)
        detail.hidesBottomBarWhenPushed = false

        if detail.parent == nil, detail.view.superview == nil {
            // The pop settled synchronously (iOS 26, and any swap outside a transition) — move now,
            // in the same pass.
            detailContainer.setContent(detail)
        } else if sizeTransitionCoordinator != nil {
            settleDetailIntoColumn(detail)
        } else {
            Log("PasswordsNavigationFlowController: list nav did not release the open detail outside a size transition; leaving it in place", module: .ui, severity: .error)
        }
    }

    /// Completes the tab → split detail move after the size transition ends. Outside the transition
    /// an explicit detach is honored, so if the nav still hasn't finalized the deferred pop, detach
    /// the detail manually before installing it in the column; bail out (without crashing) if the
    /// detail was closed in the meantime or the nav somehow still holds it.
    private func settleDetailIntoColumn(_ detail: ItemDetailViewController) {
        guard openDetailViewController === detail, let detailContainer,
              detail.parent !== detailContainer else { return }
        if detail.parent != nil || detail.view.superview != nil {
            detail.unplaceFromParent()
        }
        guard detail.parent == nil else {
            Log("PasswordsNavigationFlowController: list nav did not release the open detail; leaving it in place", module: .ui, severity: .error)
            return
        }
        detailContainer.setContent(detail)
    }

    /// Re-opens `itemID` as a fresh detail pushed onto the list nav after a split→tab swap, and clears
    /// the (off-window) detail column of the discarded instance. Fresh rather than moved — see
    /// `rehostDetail`'s note on the single scroll-observer constraint. The guards are cheap defense
    /// in depth: the same item must still be open, the detail column must still be hidden, and the
    /// old instance must not still sit on the list nav (an iOS 18 pop that never finalized) —
    /// pushing then would stack a duplicate on top of it.
    private func reopenDetailInListNav(itemID: ItemID) {
        guard let openDetail = openDetailViewController,
              openDetail.presenter.itemID == itemID,
              isDetailColumnVisible == false,
              navigationController.viewControllers.contains(openDetail) == false else { return }
        detailContainer?.setContent(ItemDetailPlaceholderViewController())
        openDetailViewController = ItemDetailFlowController.push(
            on: navigationController,
            parent: self,
            itemID: itemID,
            animated: false
        )
    }
}

private extension PasswordsNavigationFlowController {
    var listViewController: PasswordsViewController? {
        navigationController.viewControllers.first as? PasswordsViewController
    }
}
