// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common
import Data

private struct Constants {
    static let maxSelectedTagBannerWidth: CGFloat = 500
    static let contentTypePickerHeight: CGFloat = 44
    static let searchTransitioningLayoutAnimationDuration = 0.3
    static let changeScrollContentInsetAnimationDuration = 0.3
    static let showSelectedTagBannerAnimationDuration = 0.15
}

final class PasswordsViewController: UIViewController {
    var presenter: PasswordsPresenter!

    /// How this list is embedded. Set by the flow controller before the view loads; drives every
    /// layout decision that used to branch on `UIDevice.isiPad` (search bar, content-type picker,
    /// filter banner placement, selection title, tab bar hiding).
    var listLayout: PasswordsListLayout = .standalone

    /// Set by the flow controller (`setReparenting`) for the duration of a host swap, when
    /// `MainContainerViewController` moves this list between the split's supplementary column and the tab
    /// bar. A swap fires unreliable appearance callbacks: spurious ones (detaching from the old host
    /// fires `viewWillDisappear` with no matching `viewWillAppear` even though the list stays on screen)
    /// and swallowed genuine ones (the pop that reveals the list when its open detail is lifted into the
    /// split's column, or the list landing in an unselected tab). While this is set, appearance callbacks
    /// are ignored; when it clears, `reconcileAppearanceState()` settles the appearance-paired state —
    /// the vault-change observer, keyboard inset tracking — against the list's actual window attachment,
    /// so neither a spurious nor a swallowed callback can desync it. The controlled reload for a swap is
    /// driven by `reloadListAfterReparent` instead.
    var isReparenting = false {
        didSet {
            guard oldValue, isReparenting == false else { return }
            reconcileAppearanceState()
        }
    }

    /// Whether the appearance-paired state (vault-change observer, keyboard inset tracking) is
    /// currently active. Tracked explicitly so activation/deactivation are idempotent and can be
    /// reconciled against ground truth after a host swap, instead of trusting UIKit's callback pairing.
    private var isAppearanceStateActive = false

    private let searchController = CommonSearchController()
    private var layout: UICollectionViewCompositionalLayout!
    /// Inputs the compositional layout was last built from. `reloadLayout` compares against them to
    /// skip the full `setCollectionViewLayout` invalidation when nothing the layout depends on has
    /// changed — callers (every `viewWillAppear`, picker toggles, layout swaps) can't tell in
    /// advance whether the filter state actually moved while the list was off-screen.
    private struct ListLayoutInputs: Equatable {
        let topInset: CGFloat
        let showSectionHeaders: Bool
    }
    private var appliedLayoutInputs: ListLayoutInputs?
    private(set) var passwordsList: PasswordsListView?
    private(set) var dataSource: UICollectionViewDiffableDataSource<ItemSectionData, ItemCellData>?

    private(set) var emptyList: UIView?
    private(set) var emptySearchList: UIView?

    private var selectAllButton: UIBarButtonItem?
    private var selectedItemIDs: [ItemID] {
        passwordsList?.indexPathsForSelectedItems?.compactMap { indexPath in
            dataSource?.itemIdentifier(for: indexPath)?.itemID
        } ?? []
    }
    
    var contentTypePicker: UIView? {
        contentTypePickerViewController?.view
    }
    
    private var isSearchTransitioning: Bool = false

    private let selectedTagBannerView = SelectedFilterView()
    /// Constraints currently positioning `selectedTagBannerView`. Tracked so the banner can be
    /// re-anchored (under-picker ↔ top-of-list) when the layout mode switches, without leaking the
    /// previous anchoring.
    private var selectedTagBannerConstraints: [NSLayoutConstraint] = []

    private var contentTypePickerViewController: UIViewController?
    private var contentTypePickerTopConstraint: NSLayoutConstraint?
    private var contentTypePickerHeightConstraint: NSLayoutConstraint?
        
    private var edgeEffectView: UIView?
    private var edgeEffectToContentTypePickerConstraint: NSLayoutConstraint?
    private var edgeEffectToSelectedTagConstraint: NSLayoutConstraint?
    private var deleteBarButton: UIBarButtonItem?
    private var protectionLevelBarButton: UIBarButtonItem?
    private var tagsBarButton: UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(resource: .mainBackground)

        setupNavigationBar()
        setupPasswordsList()
        setupNavigationItems()
        setupDelegates()
        setupEmptyLists()
        setupDataSource()
        
        addContentTypePicker()
        
        if let contentTypePicker {
            addSelectedTagBanner(below: contentTypePicker)
            addTopEdgeEffect(contentTypePicker: contentTypePicker)
        } else if listLayout == .splitColumn {
            // The split's list column has no inline picker, but a sidebar-set filter should still
            // surface the selected-filter banner at the top of the list.
            addSelectedTagBanner()
        }

        filterDidChange(animated: false)
    }

    /// The list's own search controller, exposed so the split's detail column can host the same bar
    /// (and keep its typed phrase / cursor) while this list is embedded as the split's list column.
    var ownSearchController: CommonSearchController { searchController }

    /// Whether this list hosts its own search bar on its nav item: always in `.standalone`
    /// (tab / AutoFill), and in `.splitColumn` only before iOS 26 (from iOS 26 the split's search bar
    /// lives in the detail column instead).
    private var hostsOwnSearchBar: Bool {
        switch listLayout {
        case .standalone: return true
        case .splitColumn: return PasswordsListLayout.splitHostsSearchInDetailColumn == false
        }
    }

    /// Switches this list between its standalone and split-column presentations at runtime, so a single
    /// instance can be reparented between the tab bar and the iPad split without being rebuilt. Idempotent
    /// and safe to call repeatedly; stores the value and defers to `viewDidLoad` if the view isn't loaded.
    func applyLayout(_ newLayout: PasswordsListLayout) {
        guard isViewLoaded else { listLayout = newLayout; return }
        guard newLayout != listLayout else { return }
        listLayout = newLayout

        switch newLayout {
        case .splitColumn:
            // The list drops the inline picker + edge effect and re-anchors the filter banner to the
            // top of the list. Its search bar moves to the detail column only on iOS 26+; before that
            // it keeps (or restores) its own bar on the list column.
            if PasswordsListLayout.splitHostsSearchInDetailColumn {
                relinquishOwnSearchController()
            } else {
                reclaimOwnSearchController()
            }
            removeTopEdgeEffect()
            removeContentTypePicker()
            addSelectedTagBanner()
        case .standalone:
            // The list reclaims its own chrome: inline picker, edge effect, under-picker banner, search bar.
            addContentTypePicker()
            if let contentTypePicker {
                addTopEdgeEffect(contentTypePicker: contentTypePicker)
                addSelectedTagBanner(below: contentTypePicker)
            }
            reclaimOwnSearchController()

            // Follow the presenter's picker visibility rather than showing unconditionally: on an
            // empty vault it stays hidden, and the `hasItems` didSet can't correct an unconditional
            // show because the value doesn't change across the swap (false → false). Constraint/alpha
            // only — the single layout rebuild happens in the `filterDidChange` closing this method.
            setContentTypePickerVisible(presenter.showContentTypePicker)
        }

        // Re-evaluate the cell highlight (split column vs grid) on the next layout pass without rebuilding
        // the data source, then refresh banner/edge/layout state and the multiselect title placement.
        lastEvaluatedListBoundsSize = nil
        appliedInsetSelectionHighlight = nil
        view.setNeedsLayout()
        filterDidChange(animated: false)
        if isEditing { updateSelectionUI() }
    }

    /// Removes this list's own search bar from its nav item so the detail column can host it (split mode).
    private func relinquishOwnSearchController() {
        if navigationItem.searchController === searchController {
            navigationItem.searchController = nil
        }
    }

    /// Re-installs this list's own search bar on its nav item (standalone mode).
    private func reclaimOwnSearchController() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    /// Cells use the inset selection highlight when the list renders as a multi-column grid or as the
    /// split's list column. Read by the cell registration (see `setupDataSource`).
    var usesInsetSelectionHighlight: Bool {
        listLayout == .splitColumn || isShowingMultipleColumns
    }

    /// Whether the grid is currently laying items out in more than one column. Mirrors the column math
    /// in `ItemListLayout` using the list's current content width.
    private var isShowingMultipleColumns: Bool {
        guard let passwordsList else { return false }
        let availableWidth = passwordsList.bounds.inset(by: passwordsList.adjustedContentInset).width
        return ItemListLayout.numberOfColumns(
            forAvailableWidth: availableWidth,
            contentSizeCategory: traitCollection.preferredContentSizeCategory
        ) > 1
    }

    /// Last list bounds size we evaluated the highlight for, and the value applied for it. A bounds
    /// change can flip the multi-column state, so we re-evaluate on every bounds change and reconfigure
    /// the cells when the highlight actually changes — without rebuilding the data source.
    private var lastEvaluatedListBoundsSize: CGSize?
    private var appliedInsetSelectionHighlight: Bool?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard let boundsSize = passwordsList?.bounds.size, boundsSize != lastEvaluatedListBoundsSize else { return }
        lastEvaluatedListBoundsSize = boundsSize

        let current = usesInsetSelectionHighlight
        guard current != appliedInsetSelectionHighlight else { return }
        appliedInsetSelectionHighlight = current

        guard var snapshot = dataSource?.snapshot(), snapshot.numberOfItems > 0 else { return }
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource?.apply(snapshot, animatingDifferences: false)
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        if isSearchTransitioning {
            UIView.animate(withDuration: Constants.searchTransitioningLayoutAnimationDuration) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - App events
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // A host swap fires unreliable appearance callbacks; ignore them — clearing `isReparenting`
        // reconciles the appearance-paired state afterwards.
        guard isReparenting == false else { return }
        activateAppearanceState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard isReparenting == false else { return }
        // Idempotent — catches an appearance whose `viewWillAppear` was swallowed inside a swap
        // bracket but whose transition completed after it ended.
        activateAppearanceState()
        // Re-apply after the appearance transition completes; a text set in viewWillAppear can be
        // dropped before the search bar is laid out, leaving the restored phrase invisible.
        presenter.viewDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isReparenting == false else { return }
        deactivateAppearanceState()
    }

    private func activateAppearanceState() {
        guard isAppearanceStateActive == false else { return }
        isAppearanceStateActive = true
        presenter.viewWillAppear()
        startSafeAreaKeyboardAdjustment()
    }

    private func deactivateAppearanceState() {
        guard isAppearanceStateActive else { return }
        isAppearanceStateActive = false
        presenter.viewWillDisappear()
        stopSafeAreaKeyboardAdjustment()
    }

    /// Settles the appearance-paired state on ground truth once a host swap's callback churn is over:
    /// a swap can swallow a genuine appear (the pop revealing the list on tab→split) or a genuine
    /// disappear (the list landing in an unselected tab, or being covered by the reopened detail, on
    /// split→tab), so the callbacks alone can leave the state stuck. Window attachment is the fact.
    private func reconcileAppearanceState() {
        if viewIfLoaded?.window != nil {
            activateAppearanceState()
        } else {
            deactivateAppearanceState()
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        if editing == false {
            navigationItem.title = String(localized: .homeTitle)
            if hostsOwnSearchBar {
                navigationItem.searchController = searchController
            }

            if presenter.isAutoFillExtension {
                navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
            } else {
                navigationItem.leftBarButtonItem = nil
            }
        } else if listLayout == .splitColumn {
            // When the detail column hosts the search bar (iOS 26+) the list's nav item has none, so
            // this is a no-op there; pre-26 the list keeps its own bar (disabled below) during
            // multiselect, mirroring standalone.
            if hostsOwnSearchBar == false {
                navigationItem.searchController = nil
            }
            // The selection count lives in the detail column for the split, so clear the list
            // column's title while multiselecting instead of leaving the stale "Home" title.
            navigationItem.title = nil
        }

        searchController.searchBar.isEnabled = !editing

        passwordsList?.isEditing = editing
        // Clear the current selection on every editing transition. Entering multiselect drops the
        // split layout's persistent detail highlight so it starts with nothing selected; exiting
        // clears the multiselect checkmarks. `reconcileSelection` re-applies any cross-layout
        // selection afterwards, so this doesn't fight the restore.
        clearSelection()

        // Mirror the editing state into the shared list state so the other layout resumes in (or out
        // of) multiselect after a layout switch.
        presenter.onEditingChanged(editing)

        updateNavigationBarButtons(animated: animated)
        updateTabBarAndToolbar(isEditing: editing, animated: animated)
        updateSelectionUI()
    }
    
    func updateNavigationBarButtons() {
        if isEditing {
            configureSelectionNavigationItems()
            return
        }

        if #available(iOS 26, *) {
            let addButton = UIBarButtonItem(
                image: UIImage(systemName: "plus"),
                style: .plain,
                target: self,
                action: #selector(addAction)
            )

            addButton.tintColor = UIColor(hexString: "#007CF9", transparency: 0.8)
            addButton.style = .prominent

            if presenter.hasItems {
                navigationItem.rightBarButtonItems = [
                    addButton,
                    .fixedSpace(0),
                    filterBarButton()
                ]
            } else {
                navigationItem.rightBarButtonItems = [addButton]
            }
            
        } else {
            let addButton = UIBarButtonItem(
                image: UIImage(systemName: "plus.circle.fill"),
                style: .plain,
                target: self,
                action: #selector(addAction)
            )

            if presenter.hasItems {
                navigationItem.rightBarButtonItems = [
                    addButton,
                    filterBarButton()
                ]
            } else {
                navigationItem.rightBarButtonItems = [addButton]
            }
        }
    }
    
    func reloadLayout(animated: Bool) {
        view.layoutIfNeeded()

        let hasActiveFilter = presenter.selectedFilterTag != nil || presenter.selectedFilterProtectionLevel != nil
        // The split's list sits below a top-anchored banner; give it extra room so the first row clears it.
        let bannerExtraSpacing = listLayout == .splitColumn ? Spacing.l : 0
        let topContentInset: CGFloat = hasActiveFilter
            ? selectedTagBannerView.frame.height + Spacing.m + (presenter.showContentTypePicker ? 0 : Spacing.l) + bannerExtraSpacing
            : 0
        if passwordsList?.contentInset.top != topContentInset {
            UIView.animate(withDuration: Constants.changeScrollContentInsetAnimationDuration) {
                self.passwordsList?.contentInset.top = topContentInset
            }
        }

        guard listLayoutInputs != appliedLayoutInputs else { return }
        layout = makeLayout()
        passwordsList?.setCollectionViewLayout(layout, animated: animated)
    }
    
    func filterDidChange() {
        filterDidChange(animated: true)
    }
    
    func filterDidChange(animated: Bool) {
        selectedTagBannerView.setTag(presenter.selectedFilterTag)
        selectedTagBannerView.setProtectionLevel(presenter.selectedFilterProtectionLevel)

        let hasActiveFilter = presenter.selectedFilterTag != nil || presenter.selectedFilterProtectionLevel != nil
        edgeEffectToContentTypePickerConstraint?.isActive = !hasActiveFilter
        edgeEffectToSelectedTagConstraint?.isActive = hasActiveFilter

        UIView.animate(withDuration: Constants.showSelectedTagBannerAnimationDuration) {
            self.selectedTagBannerView.alpha = hasActiveFilter ? 1 : 0
        }

        updateNavigationBarButtons()
        reloadLayout(animated: animated)
    }
    
    func setContentTypePickerOffset(_ offset: CGFloat) {
        let topOffset = offset + contentTypePickerTopOffset
        contentTypePickerTopConstraint?.constant = max(-(contentTypePicker?.frame.height ?? 0), topOffset)
        edgeEffectToContentTypePickerConstraint?.constant = max(-view.safeAreaInsets.top, offset)
    }
    
    func showContentTypeFilterPicker(_ flag: Bool) {
        setContentTypePickerVisible(flag)
        reloadLayout(animated: true)
    }

    /// Constraint/alpha part of `showContentTypeFilterPicker`, without the layout reload — for
    /// callers that already end with their own `reloadLayout` pass (`applyLayout`).
    private func setContentTypePickerVisible(_ flag: Bool) {
        contentTypePickerHeightConstraint?.constant = flag ? Constants.contentTypePickerHeight : 0
        contentTypePicker?.alpha = flag ? 1 : 0
    }

    /// Reflects the shared search phrase in this list's own search bar (iPhone). On iPad the list has
    /// no search bar — the field is hosted in the split's detail column — so this is a no-op there.
    /// Setting the text directly doesn't notify the search delegate, so it won't re-trigger filtering;
    /// the presenter already pushes the phrase into the interactor before reloading.
    func restoreSearchPhrase(_ phrase: String?) {
        let text = phrase ?? ""
        if searchController.searchBar.text != text {
            searchController.searchBar.text = text
        }
    }
    
    func clearSelection() {
        passwordsList?.indexPathsForSelectedItems?.forEach { indexPath in
            passwordsList?.deselectItem(at: indexPath, animated: false)
        }
        updateSelectionUI()
    }

    /// Reconciles this list's editing mode and selected rows to the shared multiselect state so a
    /// selection started in the other layout continues here. Called from `reloadData`'s apply
    /// completion, when the snapshot's index paths are valid. Programmatic selection doesn't notify
    /// the delegate, so it won't loop.
    func reconcileSelection() {
        guard presenter.isSelecting else {
            if isEditing {
                setEditing(false, animated: false)
            }
            return
        }

        // Captured before `setEditing`, whose `updateSelectionUI` transiently rewrites the shared set.
        let ids = presenter.selectedItemIDs

        if isEditing == false {
            setEditing(true, animated: false)
        }

        guard let dataSource, let passwordsList else { return }

        let cellByID = Dictionary(
            dataSource.snapshot().itemIdentifiers.map { ($0.itemID, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        let currentlySelected = passwordsList.indexPathsForSelectedItems ?? []

        // Deselect anything no longer in the target set.
        for indexPath in currentlySelected {
            if let id = dataSource.itemIdentifier(for: indexPath)?.itemID, ids.contains(id) == false {
                passwordsList.deselectItem(at: indexPath, animated: false)
            }
        }
        // Select everything in the target set that isn't already selected.
        for id in ids {
            guard let cell = cellByID[id], let indexPath = dataSource.indexPath(for: cell) else { continue }
            if currentlySelected.contains(indexPath) == false {
                passwordsList.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
        }

        updateSelectionUI()
    }
}

private extension PasswordsViewController {
    
    var contentTypePickerTopOffset: CGFloat {
        if #available(iOS 26.0, *) {
            0
        } else {
            Spacing.s
        }
    }
    
    @objc
    func addAction(sender: UIBarButtonItem) {
        presenter.onAdd(sourceItem: sender)
    }
    
    @objc
    func cancel() {
        presenter.onCancel()
    }

    @objc
    func startEditingMode() {
        setEditing(true, animated: true)
    }

    @objc
    func stopEditingMode() {
        setEditing(false, animated: true)
    }

    @objc
    func selectAllAction() {
        guard let dataSource else { return }
        let allItems = dataSource.snapshot().itemIdentifiers
        if selectedItemIDs.count == allItems.count, allItems.isEmpty == false {
            passwordsList?.indexPathsForSelectedItems?.forEach { indexPath in
                passwordsList?.deselectItem(at: indexPath, animated: false)
            }
        } else {
            for item in allItems {
                guard let indexPath = dataSource.indexPath(for: item) else { continue }
                passwordsList?.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
        }

        updateSelectionUI()
        persistSelection()
    }

    @objc
    func deleteSelectedItems() {
        presenter.onDeleteItems(selectedItemIDs, source: deleteBarButton)
    }

    @objc
    func changeProtectionLevel() {
        guard selectedItemIDs.isEmpty == false else { return }
        presentBulkProtectionLevelSelection(for: selectedItemIDs)
    }

    @objc
    func changeTagsForSelectedItems() {
        guard selectedItemIDs.isEmpty == false else { return }
        presentBulkTagsSelection(for: selectedItemIDs)
    }
    
    /// True only while a split view is actively showing its sidebar (iPad wide layout), where the
    /// sidebar owns the filters. When the list is standalone (tab layout, iPhone), the list's own
    /// menu owns the filters. Derived from `listLayout` — the coordinator sets it synchronously
    /// before the swap's button/layout updates run, whereas `splitViewController.isCollapsed`
    /// still reports its initial `true` between the first attach and the split's first layout
    /// pass, which left the more button's filter dot showing alongside the sidebar's own filters.
    private var isShowingSplitSidebar: Bool {
        listLayout == .splitColumn
    }

    func filterBarButton() -> UIBarButtonItem {
        let button = FilterButton()
        // While the split's sidebar is showing, the active-filter state lives there, so don't mark the list's more button.
        button.isFilterActive = isShowingSplitSidebar == false
            && (presenter.selectedFilterTag != nil || presenter.selectedFilterProtectionLevel != nil)
        button.menu = filterMenu()
        button.showsMenuAsPrimaryAction = true
        button.clipsToBounds = false
        button.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(button)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 44),
            container.heightAnchor.constraint(equalToConstant: 44)
        ])
        button.pinToParent()

        let filterButton = UIBarButtonItem(customView: container)

        if #available(iOS 26.0, *) {
            filterButton.sharesBackground = false
            filterButton.hidesSharedBackground = true
        }

        return filterButton
    }
    
    private var listLayoutInputs: ListLayoutInputs {
        ListLayoutInputs(
            topInset: presenter.showContentTypePicker && contentTypePicker != nil ? (contentTypePicker?.frame.height ?? 0) + Spacing.l : 0,
            showSectionHeaders: presenter.hasSuggestedItems
        )
    }

    func makeLayout() -> UICollectionViewCompositionalLayout {
        let inputs = listLayoutInputs
        appliedLayoutInputs = inputs
        return ItemListLayout(
            topInset: inputs.topInset,
            showSectionHeaders: inputs.showSectionHeaders
        )
    }
    
    func addContentTypePicker() {
        // In the split, the content-type filter lives in the sidebar, so the inline picker (and its
        // dependent selected-tag banner / edge effect) is omitted for the list column.
        guard listLayout == .standalone else { return }
        // Idempotent: a repeat call (e.g. after a layout switch back to standalone) must not add a
        // duplicate child / subview.
        guard contentTypePickerViewController == nil else { return }

        let filters = ItemContentTypeFilter.allKnown

        // Seed from the shared filter state, not a constant: the picker is rebuilt on every swap back
        // to standalone, and a filter picked in the split's sidebar must stay selected (and clearable)
        // in the rebuilt inline picker.
        let pickerController = UIHostingController(rootView: ItemContentTypePickerUIKitWrapper(
            initialFilter: presenter.contentTypeFilter,
            filters: filters,
            onChange: { [weak self] filter in
                self?.presenter.onSetContentTypeFilter(filter)
            }
        ))
        contentTypePickerViewController = pickerController

        let contentTypePicker = pickerController.view!
        contentTypePicker.translatesAutoresizingMaskIntoConstraints = false
        contentTypePicker.backgroundColor = .clear

        addChild(pickerController)
        view.addSubview(contentTypePicker)

        let contentTypePickerTopConstraint = contentTypePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: contentTypePickerTopOffset)
        let contentTypePickerHeightConstraint = contentTypePicker.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            contentTypePickerTopConstraint,
            contentTypePicker.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            contentTypePicker.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            contentTypePickerHeightConstraint
        ])
        self.contentTypePickerTopConstraint = contentTypePickerTopConstraint
        self.contentTypePickerHeightConstraint = contentTypePickerHeightConstraint

        pickerController.didMove(toParent: self)
    }

    /// Tears down the inline content-type picker child (split mode has no inline picker). Symmetric to
    /// `addContentTypePicker`, including deactivating its constraints so the offset setters become no-ops.
    func removeContentTypePicker() {
        guard let pickerController = contentTypePickerViewController else { return }
        pickerController.unplaceFromParent()
        contentTypePickerTopConstraint?.isActive = false
        contentTypePickerTopConstraint = nil
        contentTypePickerHeightConstraint?.isActive = false
        contentTypePickerHeightConstraint = nil
        contentTypePickerViewController = nil
    }
    
    /// Installs the selected-filter banner. With `contentTypePicker` the banner hangs below the
    /// inline picker (standalone list); without it, it anchors to the top safe area (the split's
    /// list column, which has no inline picker).
    func addSelectedTagBanner(below contentTypePicker: UIView? = nil) {
        resetSelectedTagBanner()
        selectedTagBannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectedTagBannerView)

        // Anchor the leading edge so the banner width resolves to the chips' intrinsic size; a
        // centerX-only layout leaves the width ambiguous and collapses the chip's label.
        let leading = selectedTagBannerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Spacing.l)
        leading.priority = .defaultHigh

        if let contentTypePicker {
            let top = selectedTagBannerView.topAnchor.constraint(equalTo: contentTypePicker.bottomAnchor, constant: Spacing.l)
            top.priority = .defaultHigh

            selectedTagBannerConstraints = [
                selectedTagBannerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.m),
                top,
                selectedTagBannerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Spacing.l),
                selectedTagBannerView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Spacing.l),
                leading
            ]
        } else {
            selectedTagBannerConstraints = [
                selectedTagBannerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.m),
                leading,
                selectedTagBannerView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Spacing.l)
            ]
        }
        NSLayoutConstraint.activate(selectedTagBannerConstraints)

        selectedTagBannerView.onTagClose = { [weak self] _ in
            self?.presenter.onClearFilterTag()
        }

        selectedTagBannerView.onProtectionLevelClose = { [weak self] _ in
            self?.presenter.onClearFilterProtectionLevel()
        }
    }

    /// Split variant: pin the selected-filter banner to the top of the list (no inline picker to follow).

    /// Deactivates the banner's current anchoring so it can be re-anchored for the other layout mode.
    private func resetSelectedTagBanner() {
        NSLayoutConstraint.deactivate(selectedTagBannerConstraints)
        selectedTagBannerConstraints = []
    }

    func addTopEdgeEffect(contentTypePicker: UIView) {
        if #available(iOS 26.0, *), let passwordsList {
            guard edgeEffectView == nil else { return }

            let effectView = EdgeEffectView(edge: .top, scrollView: passwordsList)

            effectView.translatesAutoresizingMaskIntoConstraints = false
            view?.insertSubview(effectView, at: 0)

            edgeEffectToSelectedTagConstraint = effectView.bottomAnchor.constraint(equalTo: selectedTagBannerView.bottomAnchor)
            edgeEffectToContentTypePickerConstraint = effectView.bottomAnchor.constraint(equalTo: contentTypePicker.bottomAnchor)

            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: view.topAnchor),
                effectView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            ])

            edgeEffectView = effectView
        }
    }

    /// Tears down the top edge effect (no inline picker in split mode for it to track). Must run before
    /// `removeContentTypePicker`, since one of its constraints is pinned to the picker.
    func removeTopEdgeEffect() {
        edgeEffectToContentTypePickerConstraint?.isActive = false
        edgeEffectToContentTypePickerConstraint = nil
        edgeEffectToSelectedTagConstraint?.isActive = false
        edgeEffectToSelectedTagConstraint = nil
        edgeEffectView?.removeFromSuperview()
        edgeEffectView = nil
    }
    
    func setupPasswordsList() {
        layout = makeLayout()
        let passwordsList = PasswordsListView(frame: .zero, collectionViewLayout: layout)
        passwordsList.allowsSelectionDuringEditing = true
        passwordsList.allowsMultipleSelectionDuringEditing = true
        self.passwordsList = passwordsList
        view.addSubview(passwordsList)
        passwordsList.pinToParent()
        passwordsList.configure(isAutoFillExtension: presenter.isAutoFillExtension)
    }

    func setupNavigationItems() {
        searchController.delegate = self

        // In the iOS 26+ split the items search lives in the detail column (far right of the screen),
        // not on the list column. Every other case — the standalone list (tab bar, AutoFill) and the
        // pre-26 split list column — hosts its own search bar.
        if hostsOwnSearchBar {
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        }

        navigationItem.largeTitleDisplayMode = .never

        title = String(localized: .homeTitle)
        
        updateNavigationBarButtons()
        
        if presenter.isAutoFillExtension {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        }
    }
    
    func setupNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }
    
    func setupDelegates() {
        searchController.searchBarDelegate = self
        passwordsList?.delegate = self
    }
    
    func setupEmptyLists() {
        let emptySearchViewController = UIHostingController(rootView: EmptySearchView())
        addChild(emptySearchViewController)
        view.addSubview(emptySearchViewController.view)
        emptySearchViewController.view.backgroundColor = .clear
        
        if presenter.isAutoFillExtension, #available(iOS 26, *) {
            emptySearchViewController.view?.pinToParentCenter()
        } else {
            emptySearchViewController.view?.pinToSafeAreaParentCenter()
        }
        
        emptySearchViewController.didMove(toParent: self)
        
        emptySearchList = emptySearchViewController.view
        emptySearchList?.isHidden = true
        
        let emptyListViewController = UIHostingController(
            rootView: EmptyPasswordListView(onQuickSetup: { [weak self] in
                self?.presenter.onQuickSetup()
            })
            .quickSetupHidden(presenter.isAutoFillExtension)
        )
        addChild(emptyListViewController)
        view.addSubview(emptyListViewController.view)
        emptyListViewController.view.backgroundColor = .clear
        
        if presenter.isAutoFillExtension, #available(iOS 26, *) {
            emptyListViewController.view?.pinToParentCenter()
        } else {
            emptyListViewController.view?.pinToSafeAreaParentCenter()
        }
        
        emptyListViewController.didMove(toParent: self)
        
        emptyList = emptyListViewController.view
        emptyList?.isHidden = true
    }
    
    func setupDataSource() {
        guard let passwordsList else { return }

        let cellRegistration = UICollectionView.CellRegistration<ItemCellView, ItemCellData> { [weak self] cell, indexPath, item in
            cell.usesInsetSelectionHighlight = self?.usesInsetSelectionHighlight ?? false
            cell.update(with: item)
            
            if let url = item.iconType.iconURL, let cachedData = self?.presenter.cachedImage(from: url) {
                cell.updateIcon(wirh: cachedData)
            }
            
            cell.normalizeURI = { [weak self] uri in
                self?.presenter.normalizedURL(for: uri)
            }
            cell.menuAction = { [weak self] action, itemID, selectedURI in
                self?.presenter.onCellMenuAction(action, itemID: itemID, selectedURI: selectedURI)
            }
        }
        
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: passwordsList,
            cellProvider: { collectionView, indexPath, item -> UICollectionViewCell? in
                collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
            })

        dataSource?.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                let headerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: ItemListSectionView.reuseIdentifier,
                    for: indexPath
                ) as? ItemListSectionView

                let passwordSection = self?.dataSource?.snapshot().sectionIdentifiers[indexPath.section] as? ItemSectionData
                headerView?.titleLabel.text = passwordSection?.title

                return headerView

            default:
                return nil
            }
        }
        
        presenter.onImageFetchResult = { [weak self] item, url, result in
            guard let dataSource = self?.dataSource else { return }

            switch result {
            case .success(let imageData):
                guard let indexPath = dataSource.indexPath(for: item),
                      let cell = self?.passwordsList?.cellForItem(at: indexPath) as? ItemCellView else {
                    return
                }
                cell.updateIcon(with: imageData, for: item)
            case .failure:
                break
            }
        }
    }
    
    func filterMenu() -> UIMenu {
        UIMenu(
            children: [UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.filterMenuItems() ?? [])
            }]
        )
    }

    func selectMenuAction() -> UIAction {
        UIAction(
            title: String(localized: .homeListMenuSelect),
            image: UIImage(systemName: "checkmark.circle")
        ) { [weak self] _ in
            self?.startEditingMode()
        }
    }

    func configureSelectionNavigationItems() {
        let selectAllButton = UIBarButtonItem(title: selectAllButtonTitle(), style: .plain, target: self, action: #selector(selectAllAction))
        self.selectAllButton = selectAllButton
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(stopEditingMode))
        navigationItem.rightBarButtonItems = [
            selectAllButton,
            filterBarButton()
        ]
        updateSelectionUI()
    }

    func selectAllButtonTitle() -> String {
        guard let dataSource else {
            return String(localized: .homeSelectionSelectAll)
        }
        let allCount = dataSource.snapshot().itemIdentifiers.count
        return selectedItemIDs.count == allCount && allCount > 0
            ? String(localized: .homeSelectionDeselectAll)
            : String(localized: .homeSelectionSelectAll)
    }


    func updateNavigationBarButtons(animated: Bool = false) {
        if animated, let navigationBar = navigationController?.navigationBar {
            UIView.transition(with: navigationBar, duration: 0.25, options: .transitionCrossDissolve) {
                self.updateNavigationBarButtons()
            }
        } else {
            updateNavigationBarButtons()
        }
    }

    func updateTabBarAndToolbar(isEditing: Bool, animated: Bool) {
        let deleteBarButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(deleteSelectedItems)
        )
        deleteBarButton.isEnabled = selectedItemIDs.isEmpty == false
        self.deleteBarButton = deleteBarButton
        
        let protectionLevelBarButton = UIBarButtonItem(
            image: UIImage(resource: .tier3Icon),
            style: .plain,
            target: self,
            action: #selector(changeProtectionLevel)
        )
        protectionLevelBarButton.accessibilityLabel = String(localized: .settingsEntryProtectionLevel)
        protectionLevelBarButton.isEnabled = selectedItemIDs.isEmpty == false
        self.protectionLevelBarButton = protectionLevelBarButton

        let tagsBarButton = UIBarButtonItem(
            image: UIImage(systemName: "tag"),
            style: .plain,
            target: self,
            action: #selector(changeTagsForSelectedItems)
        )
        tagsBarButton.isEnabled = selectedItemIDs.isEmpty == false
        self.tagsBarButton = tagsBarButton

        let toolbarItems = [
            protectionLevelBarButton,
            UIBarButtonItem.fixedSpace(0),
            tagsBarButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteBarButton
        ]
        setToolbarItems(toolbarItems, animated: false)
        navigationController?.setToolbarHidden(!isEditing, animated: animated)

        guard let tabBar = tabBarController?.tabBar else { return }

        if #available(iOS 26.0, *) {
            if isEditing {
                if animated {
                    tabBar.isHidden = false
                    UIView.animate(withDuration: 0.25, animations: {
                        tabBar.alpha = 0
                    }, completion: { _ in
                        tabBar.isHidden = true
                    })
                } else {
                    tabBar.alpha = 0
                    tabBar.isHidden = true
                }
            } else {
                if animated {
                    tabBar.isHidden = false
                    tabBar.alpha = 0
                    UIView.animate(withDuration: 0.25) {
                        tabBar.alpha = 1
                    }
                } else {
                    tabBar.alpha = 1
                    tabBar.isHidden = false
                }
            }
        } else if #available(iOS 18.0, *) {
            tabBarController?.setTabBarHidden(isEditing, animated: animated)
        }
    }

    func presentBulkProtectionLevelSelection(for itemIDs: [ItemID]) {
        presenter.toBulkProtectionLevelSelection(selectedItemIDs: itemIDs)
    }

    func presentBulkTagsSelection(for itemIDs: [ItemID]) {
        presenter.toBulkTagsSelection(selectedItemIDs: itemIDs)
    }

    func filterMenuItems() -> [UIMenuElement] {
        var menuItems: [UIMenuElement] = []
        menuItems.append(sortMenu())
        // Filters live in the sidebar while the split shows it, so omit them from the list's menu then.
        if isShowingSplitSidebar == false {
            menuItems.append(tagMenu())
        }
        if isEditing == false, presenter.isAutoFillExtension == false {
            let selectSection = UIMenu(title: "", options: .displayInline, children: [selectMenuAction()])
            menuItems.append(selectSection)
        }
        return menuItems
    }
    
    func tagMenu() -> UIMenu {
        // One storage pass for every row's count, instead of one query per level / per tag.
        let counts = presenter.itemFilterCounts()

        // Create protection level actions
        let protectionLevelActions = ItemProtectionLevel.allCases.map { level in
            let count = counts.byProtectionLevel[level] ?? 0
            let title = "\(level.title) (\(count))"
            return UIAction(
                title: title,
                image: level.uiIcon.withTintColor(.accent),
                state: presenter.selectedFilterProtectionLevel == level ? .on : .off
            ) { [weak self] _ in
                self?.presenter.onSelectFilterProtectionLevel(level)
            }
        }

        let tags = presenter.listAllTags()

        // Create tag actions
        let tagActions: [UIMenuElement]
        if tags.isEmpty {
            let noTagsLabel = UIAction(
                title: String(localized: .loginFilterModalNoTags),
                attributes: .disabled
            ) { _ in }
            tagActions = [noTagsLabel]
        } else {
            tagActions = tags.map { tag in
                let count = counts.byTag[tag.tagID] ?? 0
                let title = "\(tag.name) (\(count))"
                let colorImage = UIImage.circleImage(
                    color: UIColor(tag.color),
                    size: CGSize(width: ItemTagColorMetrics.small.size, height: ItemTagColorMetrics.small.size)
                )
                return UIAction(
                    title: title,
                    image: colorImage,
                    state: presenter.selectedFilterTag?.tagID == tag.tagID ? .on : .off
                ) { [weak self] _ in
                    self?.presenter.onSelectFilterTag(tag)
                }
            }
        }

        // Create inline menu with protection levels, separator, and tags
        let protectionLevelSection = UIMenu(title: "", options: .displayInline, children: protectionLevelActions)
        let tagSection = UIMenu(title: "", options: .displayInline, children: tagActions)

        return UIMenu(
            title: String(localized: .loginFilterModalTag),
            image: UIImage(systemName: "line.3.horizontal.decrease"),
            children: [protectionLevelSection, tagSection]
        )
    }
    
    func sortMenu() -> UIMenu {
        UIMenu(
            title: String(localized: .loginFilterModalTitle),
            image: UIImage(systemName: "arrow.up.arrow.down"),
            children: [UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.sortMenuItems() ?? [])
            }]
        )
    }
    
    func sortMenuItems() -> [UIAction] {
        SortType.allCases.map { sortType in
            UIAction(
                title: sortType.label,
                image: sortType.icon,
                state: presenter.selectedSort == sortType ? .on : .off
            ) { [weak self] _ in
                self?.presenter.onSelectSort(sortType)
            }
        }
    }
    
}

extension PasswordsViewController: CommonSearchDataSourceSearchable {
    func setSearchPhrase(_ phrase: String) {
        presenter.onSetSearchPhrase(phrase)
    }
    
    func clearSearchPhrase() {
        presenter.onClearSearchPhrase()
    }
}

extension PasswordsViewController {
    func updateSelectionUI() {
        guard isEditing else { return }
        let selectedItemIDs = selectedItemIDs
        // The split layout reports the count in its detail column instead, so keep the list column's
        // title clear there; only the standalone list shows the count in its navigation title.
        if listLayout == .standalone {
            navigationItem.title = String(localized: .homeSelectionCount(Int32(selectedItemIDs.count)))
        }
        selectAllButton?.title = selectAllButtonTitle()
        deleteBarButton?.isEnabled = selectedItemIDs.isEmpty == false
        protectionLevelBarButton?.isEnabled = selectedItemIDs.isEmpty == false
        tagsBarButton?.isEnabled = selectedItemIDs.isEmpty == false
    }

    /// Persists the current selection to the shared state. Called only from genuine user selection
    /// actions (tap, select-all) — never from transient clears like `clearSelection()`, which would
    /// otherwise wipe the shared selection the other layout is about to restore.
    func persistSelection() {
        guard isEditing else { return }
        presenter.onSelectionChanged(Set(selectedItemIDs))
    }
}

extension PasswordsViewController: UISearchControllerDelegate {
    
    func willPresentSearchController(_ searchController: UISearchController) {
        isSearchTransitioning = true
}

    func didPresentSearchController(_ searchController: UISearchController) {
        isSearchTransitioning = false
    }
    
    func willDismissSearchController(_ searchController: UISearchController) {
        isSearchTransitioning = true
    }
    
    func didDismissSearchController(_ searchController: UISearchController) {
        isSearchTransitioning = false
    }
}
