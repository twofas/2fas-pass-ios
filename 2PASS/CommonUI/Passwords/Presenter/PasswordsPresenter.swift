// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Data

private class IconFetcherProxy: RemoteImageCollectionFetcher {

    let interactor: PasswordsModuleInteracting

    init(interactor: PasswordsModuleInteracting) {
        self.interactor = interactor
    }

    func cachedImage(from url: URL) -> Data? {
        interactor.cachedImage(from: url)
    }

    func fetchImage(from url: URL) async throws -> Data {
        try await interactor.fetchIconImage(from: url)
    }
}

final class PasswordsPresenter {
    weak var view: PasswordsViewControlling?
    weak var sidebar: PasswordsSidebarViewControlling?

    var selectedSort: SortType {
        interactor.currentSortType
    }

    var isAutoFillExtension: Bool {
        autoFillEnvironment != nil
    }

    var selectedFilterTag: ItemTagData? {
        get { filterState.selectedTag }
        set {
            filterState.selectedTag = newValue
            clearSelectionForFilterChange()
            view?.filterDidChange()
            reload(sidebarUpdate: .selection)
        }
    }

    var selectedFilterProtectionLevel: ItemProtectionLevel? {
        get { filterState.selectedProtectionLevel }
        set {
            filterState.selectedProtectionLevel = newValue
            clearSelectionForFilterChange()
            view?.filterDidChange()
            reload(sidebarUpdate: .selection)
        }
    }

    var showContentTypePicker: Bool {
        if let autoFillEnvironment {
            return autoFillEnvironment.isTextToInsert && hasItems
        } else {
            return hasItems
        }
    }

    var contentTypeFilter: ItemContentTypeFilter {
        filterState.contentTypeFilter
    }

    /// Item shown in the detail column of the iPad split layout. Kept in sync with both
    /// taps and `reload()`-driven auto-selection so the two share one source of truth.
    private(set) var selectedDetailItemID: ItemID?

    private(set) var itemsCount: Int = 0
    private(set) var hasSuggestedItems = false
    private(set) var hasItems = false {
        didSet {
            guard oldValue != hasItems else {
                return
            }
            view?.showContentTypeFilterPicker(showContentTypePicker)
        }
    }

    private let autoFillEnvironment: AutoFillEnvironment?
    private let iconsDataSource: RemoteImageCollectionDataSource<ItemCellData>
    private let flowController: PasswordsFlowControlling
    private let interactor: PasswordsModuleInteracting
    /// Filter selections shared with the other layout representation so switching layouts keeps them.
    private let filterState: PasswordsFilterState
    private let toastPresenter: ToastPresenter
    private var listData: [Int: [ItemData]] = [:]
    private var tagColorsByID: [ItemTagID: ItemTagColor] = [:]
    private var isViewReady: Bool = false
    private var storageDidChangeToken: Notifications.ObservationToken?
    private var canLoadData: Bool {
        isViewReady && interactor.isUserLoggedIn
    }

    init(autoFillEnvironment: AutoFillEnvironment? = nil, flowController: PasswordsFlowControlling, interactor: PasswordsModuleInteracting, filterState: PasswordsFilterState = PasswordsFilterState()) {
        self.autoFillEnvironment = autoFillEnvironment
        self.flowController = flowController
        self.interactor = interactor
        self.filterState = filterState
        self.toastPresenter = .shared
        self.iconsDataSource = RemoteImageCollectionDataSource(fetcher: IconFetcherProxy(interactor: interactor))
    }

    deinit {
        storageDidChangeToken?.cancel()
    }
}

extension PasswordsPresenter {

    @MainActor
    func viewWillAppear() {
        isViewReady = true

        // Re-apply the shared filter state: the other layout representation may have changed the
        // search phrase or filters while this one was off-screen. The search phrase lives in the
        // interactor, so push it back before reloading; the banner/search bar are refreshed below.
        interactor.setSearchPhrase(filterState.searchPhrase)
        restoreSearchBars()
        refreshSelectedFilterTag()
        view?.filterDidChange()
        reload()

        // Register synchronously so a save posted before the observer is live isn't dropped.
        storageDidChangeToken?.cancel()
        storageDidChangeToken = NotificationCenter.default.addObserver(of: VaultDataDidChange.self) { [weak self] message in
            guard let self, message.affects([.items, .tags]) else { return }
            // The only animated reload: a real data change (first item added, last item removed) is a
            // meaningful transition, unlike the layout/appearance-driven reloads which apply instantly.
            self.reload(animated: true)
        }
    }

    /// Re-runs the list reload after the shared subtree is reparented between the split and the tab
    /// bar. The empty-state placement (blank list + detail empty screen vs the list's own empty screen)
    /// is decided inside the reload, and the reparent can skip the `viewWillAppear` that normally
    /// triggers it — see `PasswordsNavigationFlowController.reloadListAfterReparent`.
    @MainActor
    func reloadAfterReparent() {
        reload()
    }

    @MainActor
    func viewDidAppear() {
        // UISearchController drops a text set during the appearance transition, so re-assert the
        // restored phrase once the bar is laid out — covers both the standalone list's own search bar
        // and the split's detail-column search bar.
        restoreSearchBars()
    }

    @MainActor
    func viewWillDisappear() {
        storageDidChangeToken?.cancel()
        storageDidChangeToken = nil
    }

    /// Pushes the shared search phrase into whichever search bar this representation uses: the
    /// standalone list's own bar (`view`) and/or the split's detail-column bar (`flowController`).
    private func restoreSearchBars() {
        view?.restoreSearchPhrase(filterState.searchPhrase)
        flowController.restoreItemsSearchPhrase(filterState.searchPhrase)
    }

    /// The shared multiselect state, read by the view to reconcile its collection-view selection after
    /// each data apply (more reliable than appearance callbacks, which the split's list column may skip).
    var isSelecting: Bool { filterState.isSelecting }
    var selectedItemIDs: Set<ItemID> { filterState.selectedItemIDs }

    /// Called by the view when editing mode toggles. Clears the stored selection when leaving editing.
    func onEditingChanged(_ isSelecting: Bool) {
        filterState.isSelecting = isSelecting
        if isSelecting {
            // Entering multiselect: drop the split layout's persisted detail item and show the
            // selection summary in the detail column instead of the previously-viewed item.
            selectedDetailItemID = nil
            updateMultiselectDetail()
        } else {
            filterState.selectedItemIDs = []
            // Leaving multiselect: restore the detail column to its placeholder.
            flowController.clearDetailSelection()
        }
    }

    /// Called by the view whenever the selected rows change while editing.
    func onSelectionChanged(_ selectedItemIDs: Set<ItemID>) {
        filterState.selectedItemIDs = selectedItemIDs
        // Keep the split's detail column in sync with the live selection.
        updateMultiselectDetail()
    }

    /// Changing a filter drops the multiselect selection: keeping IDs the new filter hides would
    /// let bulk actions act on items the user can no longer see, and would silently re-select them
    /// when the filter is lifted. Clearing the shared state is enough for every consumer — the view
    /// deselects its rows in `reconcileSelection()` after the reload's snapshot apply, and the reload
    /// that every caller triggers next refreshes the split detail's selection summary
    /// (via `updateDetailSelectionIfNeeded`).
    private func clearSelectionForFilterChange() {
        guard filterState.isSelecting, filterState.selectedItemIDs.isEmpty == false else { return }
        filterState.selectedItemIDs = []
    }

    /// Reflects the current multiselect selection in the iPad split's detail column: a single
    /// selected item shows its full detail, otherwise the detail shows the selected count. No-op
    /// where there's no detail column (iPhone, AutoFill).
    private func updateMultiselectDetail() {
        guard flowController.isDetailColumnVisible else { return }

        let selectedItemIDs = filterState.selectedItemIDs
        if selectedItemIDs.count == 1, let itemID = selectedItemIDs.first {
            // Reloads land here repeatedly (sync ticks, viewWillAppear, filter changes); rebuilding
            // the hosted preview for the same item would reset its scroll position and revealed
            // fields. The detail observes `VaultDataDidChange` and refreshes itself in place, so a
            // same-item update needs no swap — mirroring the count branch, which updates the hosted
            // summary instead of replacing it.
            if flowController.openDetailItemID != itemID {
                flowController.toItemDetail(itemID: itemID)
            }
        } else {
            flowController.showMultiselectDetail(selectedCount: selectedItemIDs.count)
        }
    }

    /// Validates the persisted tag filter against current data (the tag may have been renamed or
    /// deleted in the other layout). Writes straight to `filterState` rather than through
    /// `selectedFilterTag` so it doesn't trigger an extra `filterDidChange()`/`reload()` — the caller
    /// (`viewWillAppear`) already does both right after.
    private func refreshSelectedFilterTag() {
        guard let selectedTag = filterState.selectedTag else { return }

        if let tag = interactor.getTag(for: selectedTag.tagID) {
            if tag != selectedTag {
                filterState.selectedTag = tag
            }
        } else {
            filterState.selectedTag = nil
        }
    }

    func onQuickSetup() {
        flowController.toQuickSetup()
    }

    func onAdd(sourceItem: UIBarButtonItem?) {
        if interactor.canAddPassword {
            flowController.toContentTypeSelection(sourceItem: sourceItem)
        } else {
            flowController.toPremiumPlanPrompt(itemsLimit: interactor.currentPlanItemsLimit)
        }
    }

    func onCancel() {
        flowController.cancel()
    }

    func onSelectSort(_ sortType: SortType) {
        interactor.setSortType(sortType)
        reload(sidebarUpdate: .none)
    }

    func onSetSearchPhrase(_ searchPhrase: String?) {
        filterState.searchPhrase = searchPhrase
        interactor.setSearchPhrase(searchPhrase)
        reload(sidebarUpdate: .none)
    }

    func onSetContentTypeFilter(_ filter: ItemContentTypeFilter) {
        filterState.contentTypeFilter = filter
        clearSelectionForFilterChange()
        reload(sidebarUpdate: .selection)
    }

    func onClearSearchPhrase() {
        filterState.searchPhrase = nil
        interactor.setSearchPhrase(nil)

        Task { @MainActor in // fix animation
            reload(sidebarUpdate: .none)
        }
    }

    func onSelectFilterTag(_ tag: ItemTagData?) {
        selectedFilterTag = tag
    }

    func onClearFilterTag() {
        selectedFilterTag = nil
    }

    func onSelectFilterProtectionLevel(_ protectionLevel: ItemProtectionLevel?) {
        selectedFilterProtectionLevel = protectionLevel
    }

    func onClearFilterProtectionLevel() {
        selectedFilterProtectionLevel = nil
    }

    func onCellMenuAction(_ action: PasswordCellMenu, itemID: ItemID, selectedURI: URL?) {
        switch action {
        case .view: flowController.toItemDetail(itemID: itemID)
        case .edit: flowController.toEditItem(itemID: itemID)
        case .copy(.loginUsername):
            if interactor.copyUsername(itemID) {
                toastPresenter.presentUsernameCopied()
            } else {
                toastPresenter.present(
                    .passwordErrorCopyUsername,
                    style: .failure
                )
            }
        case .copy(.loginPassword):
            copyPassword(id: itemID)

        case .copy(.secureNoteText):
            copySecureNote(id: itemID)

        case .copy(.paymentCardNumber):
            copyPaymentCardNumber(id: itemID)

        case .copy(.paymentCardSecurityCode):
            copyPaymentCardSecurityCode(id: itemID)
        case .copy(.wifiSSID):
            copyWiFiSSID(id: itemID)
        case .copy(.wifiPassword):
            copyWiFiPassword(id: itemID)

        case .goToURI: if let selectedURI {
            flowController.toURI(selectedURI)
        }
        case .shareLink:
            flowController.toShareLink(itemID: itemID)
        case .moveToTrash:
            Task { @MainActor in
                if await flowController.toConfirmDelete() {
                    interactor.moveToTrash(itemID)
                }
            }
        }
    }

    func onDidSelectAt(_ indexPath: IndexPath) {
        guard let itemData = item(at: indexPath) else {
            return
        }

        switch interactor.selectAction {
        case .viewDetails:
            selectedDetailItemID = itemData.id
            flowController.selectItem(id: itemData.id, contentType: itemData.contentType)
            if flowController.isDetailColumnVisible {
                view?.highlightRow(for: itemData.id)
            }
        case .copy:
            switch itemData {
            case .login:
                copyPassword(id: itemData.id)
            case .secureNote:
                copySecureNote(id: itemData.id)
            case .paymentCard:
                copyPaymentCardNumber(id: itemData.id)
            case .wifi:
                copyWiFiPassword(id: itemData.id)
            case .raw:
                break
            }

        case .goToURI:
            if let uri = itemData.asLoginItem?.uris?.first, let normalized = interactor.normalizedURL(for: uri.uri) {
                flowController.toURI(normalized)
            }
        case .edit:
            flowController.toEditItem(itemID: itemData.id)
        }
    }

    @MainActor
    func onDeleteItems(_ itemIDs: [ItemID], source: UIBarButtonItem?) {
        guard itemIDs.isEmpty == false else { return }

        Task { @MainActor in
            if await flowController.toConfirmMultiselectDelete(selectedCount: itemIDs.count, source: source) {
                interactor.moveToTrash(itemIDs)
                view?.exitEditingMode()
            }
        }
    }

    func normalizedURL(for uri: String) -> URL? {
        interactor.normalizedURL(for: uri)
    }

    func listAllTags() -> [ItemTagData] {
        interactor.listAllTags()
    }

    /// Tag and protection-level counts for the sidebar and the list's filter menu, all from a single
    /// storage pass instead of one query per tag / per protection level.
    func itemFilterCounts() -> ItemFilterCounts {
        interactor.itemFilterCounts()
    }

    func applyProtectionLevel(_ protectionLevel: ItemProtectionLevel, to itemIDs: [ItemID]) {
        do {
            try interactor.updateProtectionLevel(protectionLevel, for: itemIDs)
            view?.exitEditingMode()
        } catch {
            Log("PasswordsPresenter: Failed to update protection level", module: .ui, severity: .error)
            toastPresenter.present(.commonGeneralErrorTryAgain, style: .failure)
        }
    }

    func toBulkProtectionLevelSelection(selectedItemIDs: [ItemID]) {
        flowController.toBulkProtectionLevelSelection(
            selectedItems: selectedItems(for: selectedItemIDs)
        )
    }

    func toBulkTagsSelection(selectedItemIDs: [ItemID]) {
        flowController.toBulkTagsSelection(
            selectedItems: selectedItems(for: selectedItemIDs)
        )
    }

    func applyTagChanges(to itemIDs: [ItemID], tagsToAdd: Set<ItemTagID>, tagsToRemove: Set<ItemTagID>) {
        do {
            try interactor.applyTagChanges(to: itemIDs, tagsToAdd: tagsToAdd, tagsToRemove: tagsToRemove)
            view?.exitEditingMode()
        } catch {
            Log("PasswordsPresenter: Failed to apply tag changes", module: .ui, severity: .error)
            toastPresenter.present(.commonGeneralErrorTryAgain, style: .failure)
        }
    }
}

extension PasswordsPresenter {

    @MainActor
    var onImageFetchResult: (ItemCellData, URL, Result<Data, Error>) -> Void {
        get { iconsDataSource.onImageFetchResult }
        set { iconsDataSource.onImageFetchResult = newValue }
    }

    @MainActor
    func cachedImage(from url: URL) -> Data? {
        iconsDataSource.cachedImage(from: url)
    }

    @MainActor
    func fetchImage(from url: URL, for password: ItemCellData) {
        iconsDataSource.fetchImage(from: url, for: password)
    }

    @MainActor
    func cancelFetches(for password: ItemCellData) {
        iconsDataSource.cancelFetches(for: password)
    }
}

private extension PasswordsPresenter {

    func copyPassword(id: ItemID) {
        if interactor.copyPassword(id) {
            toastPresenter.presentPasswordCopied()
        } else {
            toastPresenter.present(
                .passwordErrorCopyPassword,
                style: .failure
            )
        }
    }

    func copySecureNote(id: ItemID) {
        if interactor.copySecureNote(id) {
            toastPresenter.presentSecureNoteCopied()
        } else {
            toastPresenter.present(
                .secureNoteErrorCopy,
                style: .failure
            )
        }
    }

    func copyPaymentCardNumber(id: ItemID) {
        if interactor.copyPaymentCardNumber(id) {
            toastPresenter.presentPaymentCardNumberCopied()
        } else {
            toastPresenter.present(
                .cardErrorCopyNumber,
                style: .failure
            )
        }
    }

    func copyPaymentCardSecurityCode(id: ItemID) {
        if interactor.copyPaymentCardSecurityCode(id) {
            toastPresenter.presentPaymentCardSecurityCodeCopied()
        } else {
            toastPresenter.present(
                .cardErrorCopySecurityCode,
                style: .failure
            )
        }
    }

    func copyWiFiSSID(id: ItemID) {
        if interactor.copyWiFiSSID(id) {
            toastPresenter.presentCopied()
        } else {
            toastPresenter.present(
                .commonGeneralErrorTryAgain,
                style: .failure
            )
        }
    }

    func copyWiFiPassword(id: ItemID) {
        if interactor.copyWiFiPassword(id) {
            toastPresenter.presentPasswordCopied()
        } else {
            toastPresenter.present(
                .passwordErrorCopyPassword,
                style: .failure
            )
        }
    }

    func item(at indexPath: IndexPath) -> ItemData? {
        listData[indexPath.section]?[safe: indexPath.item]
    }

    /// What the sidebar must re-read after a reload. The counts are full-vault storage scans, so
    /// reloads whose trigger cannot change them opt down to the cheaper levels instead of paying
    /// the scans for bit-identical results.
    enum SidebarUpdate {
        /// Vault data (items or tags) may have changed: refresh the counts and the selection mirror.
        case counts
        /// Only the selected filter changed: mirror the selection state without refetching counts.
        case selection
        /// Nothing the sidebar shows changed (search phrase, sort): skip entirely.
        case none
    }

    /// Reloads the list and re-applies the empty-state placement. `animated` is reserved for reloads
    /// caused by an actual data change (see the `VaultDataDidChange` observer) — every other trigger
    /// (appearance, reparent, search/filter/sort changes) applies instantly, because those reloads run
    /// during layout or input handling where a fade reads as a stray flicker.
    func reload(animated: Bool = false, sidebarUpdate: SidebarUpdate = .counts) {
        guard canLoadData else {
            return
        }

        listData.removeAll()
        hasSuggestedItems = false
        tagColorsByID = Dictionary(
            listAllTags().map { ($0.tagID, $0.color) },
            uniquingKeysWith: { _, new in new }
        )

        let cellsCount: Int

        if let serviceIdentifiers = autoFillEnvironment?.serviceIdentifiers, autoFillEnvironment?.isTextToInsert == false {
            let list = interactor.loadList(forServiceIdentifiers: serviceIdentifiers, contentType: .login, tag: selectedFilterTag, protectionLevel: selectedFilterProtectionLevel)

            var snapshot = NSDiffableDataSourceSnapshot<ItemSectionData, ItemCellData>()

            if list.suggested.isEmpty {
                listData[0] = list.rest

                let restCells = list.rest.compactMap(makeCellData(for:))
                let section = ItemSectionData()

                snapshot.appendSections([section])
                snapshot.appendItems(restCells, toSection: section)

                cellsCount = list.rest.count
                itemsCount = cellsCount

            } else {
                listData[0] = list.suggested
                listData[1] = list.rest
                hasSuggestedItems = true

                let suggestedCells = list.suggested.compactMap(makeCellData(for:))
                let restCells = list.rest.compactMap(makeCellData(for:))
                let suggestedSection = ItemSectionData(title: String(localized: .commonSuggested))
                let section = ItemSectionData(title: String(localized: .commonOther))

                snapshot.appendSections([suggestedSection])
                snapshot.appendItems(suggestedCells, toSection: suggestedSection)
                snapshot.appendSections([section])
                snapshot.appendItems(restCells, toSection: section)

                cellsCount = suggestedCells.count + restCells.count
                itemsCount = cellsCount
            }

            hasItems = interactor.hasItems(for: .login)
            view?.reloadData(newSnapshot: snapshot)

        } else {
            let list = interactor.loadList(contentType: contentTypeFilter.contentType, tag: selectedFilterTag, protectionLevel: selectedFilterProtectionLevel)
            listData[0] = list
            let cells = list.compactMap(makeCellData(for:))
            let section = ItemSectionData()
            var snapshot = NSDiffableDataSourceSnapshot<ItemSectionData, ItemCellData>()
            snapshot.appendSections([section])
            snapshot.appendItems(cells, toSection: section)

            cellsCount = cells.count
            itemsCount = cellsCount

            hasItems = interactor.hasItems
            view?.reloadData(newSnapshot: snapshot)
        }

        let isFiltering = interactor.isSearching || selectedFilterTag != nil || selectedFilterProtectionLevel != nil || (contentTypeFilter.contentType != nil && hasItems)

        if cellsCount == 0 {
            if isFiltering {
                view?.showSearchEmptyScreen(animated: animated)
            } else if flowController.isDetailColumnVisible {
                // Empty vault in the iPad split: keep the list column blank and show the full
                // "no items" empty screen in the wide detail column instead (see `updateDetailSelectionIfNeeded`).
                view?.showList(animated: animated)
            } else {
                view?.showEmptyScreen(animated: animated)
            }
        } else {
            view?.showList(animated: animated)
        }

        updateDetailSelectionIfNeeded(isEmptyVault: cellsCount == 0 && isFiltering == false)
        switch sidebarUpdate {
        case .counts:
            sidebar?.reloadFilters()
        case .selection:
            sidebar?.reloadSelectedFilters()
        case .none:
            break
        }
    }

    /// Keeps the iPad split's detail column in sync with the list: re-highlights the current
    /// selection if it survived the reload. It never auto-selects an item. When the vault is empty
    /// it shows the full "no items" screen in the detail column; for a filtered-empty list it falls
    /// back to the placeholder. No-op on iPhone and in the AutoFill extension.
    func updateDetailSelectionIfNeeded(isEmptyVault: Bool) {
        guard autoFillEnvironment == nil else { return }

        // Multiselect owns the detail column: it shows the selection summary (or the single selected
        // item), and `selectedDetailItemID` is deliberately nil. Falling through would replace the
        // summary with the placeholder on any reload that lands mid-selection (sync, filter change).
        if filterState.isSelecting {
            updateMultiselectDetail()
            return
        }

        guard flowController.isDetailColumnVisible else {
            // The persistent row highlight only marks the item open in the visible detail column.
            // With the column hidden (tab layout), drop the highlight but keep `selectedDetailItemID`,
            // so returning to the split restores both the parked detail and its highlight — unless
            // the pushed detail itself is gone (a back/swipe pop leaves no other trace); keeping the
            // ID then would re-highlight a row whose detail column shows only the placeholder.
            view?.clearRowHighlight()
            if flowController.openDetailItemID == nil {
                selectedDetailItemID = nil
            }
            return
        }

        // Re-highlight only while the flow controller actually hosts that item's detail: the ID can
        // outlive the detail (closed in the column, popped before a swap), and a highlight pointing
        // at a placeholder column misreads as an open detail.
        if let currentID = selectedDetailItemID, itemExistsInFilteredList(currentID),
           flowController.openDetailItemID == currentID {
            view?.highlightRow(for: currentID)
            return
        }

        // While searching, keep the current detail selection unchanged: the selected item
        // stays in the detail column even when the phrase filters its row out of the list.
        // Only a selection gone from the vault itself (deleted mid-search) falls through to
        // clear — the filtered list alone can't tell "filtered out" from "deleted".
        if interactor.isSearching {
            let selectionStillInVault = selectedDetailItemID.map { interactor.itemExists($0) } ?? true
            if selectionStillInVault {
                return
            }
        }

        // Never auto-select an item. With no surviving selection, show the empty-vault
        // detail for a truly empty vault, otherwise fall back to the placeholder.
        selectedDetailItemID = nil
        if isEmptyVault {
            flowController.showEmptyVaultDetail()
        } else {
            flowController.clearDetailSelection()
        }
    }

    /// Whether the item is present in the currently loaded (filtered) list — distinct from
    /// `interactor.itemExists`, which checks the vault regardless of the active filters.
    func itemExistsInFilteredList(_ id: ItemID) -> Bool {
        listData.values.contains { $0.contains { $0.id == id } }
    }

    func makeCellData(for itemData: ItemData) -> ItemCellData? {
        switch itemData {
        case .login(let loginItem):
            return ItemCellData(
                itemID: loginItem.id,
                name: loginItem.name,
                description: loginItem.content.username,
                iconType: .login(loginItem.content.iconType),
                tagColors: tagColors(for: itemData),
                actions: [
                    .view,
                    .edit,
                    loginItem.username != nil ? .copy(.loginUsername) : nil,
                    loginItem.password != nil ? .copy(.loginPassword) : nil,
                    isAutoFillExtension ? nil : .goToURI(uris: loginItem.content.uris?.map { $0.uri } ?? []),
                    .shareLink,
                    isAutoFillExtension ? nil : .moveToTrash
                ]
                .compactMap { $0 }
            )
        case .secureNote(let secureNoteItem):
            return ItemCellData(
                itemID: secureNoteItem.id,
                name: secureNoteItem.name,
                description: nil,
                iconType: .contentType(itemData.contentType),
                tagColors: tagColors(for: itemData),
                actions: [
                    .view,
                    .edit,
                    secureNoteItem.content.text != nil ? .copy(.secureNoteText) : nil,
                    .shareLink,
                    isAutoFillExtension ? nil : .moveToTrash
                ]
                .compactMap { $0 }
            )
        case .paymentCard(let paymentCardItem):
            let description: String? = if let mask = paymentCardItem.content.cardNumberMask {
                mask.formatted(.paymentCardNumberMask)
            } else {
                paymentCardItem.content.cardHolder
            }
            return ItemCellData(
                itemID: paymentCardItem.id,
                name: paymentCardItem.name,
                description: description,
                iconType: .paymentCard(issuer: paymentCardItem.content.cardIssuer),
                tagColors: tagColors(for: itemData),
                actions: [
                    .view,
                    .edit,
                    paymentCardItem.content.cardNumber != nil ? .copy(.paymentCardNumber) : nil,
                    paymentCardItem.content.securityCode != nil ? .copy(.paymentCardSecurityCode) : nil,
                    .shareLink,
                    isAutoFillExtension ? nil : .moveToTrash
                ]
                .compactMap { $0 }
            )
        case .wifi(let wifiItem):
            return ItemCellData(
                itemID: wifiItem.id,
                name: wifiItem.name,
                description: wifiItem.content.ssid,
                iconType: .contentType(.wifi),
                tagColors: tagColors(for: itemData),
                actions: [
                    .view,
                    .edit,
                    wifiItem.content.ssid?.isEmpty == false ? .copy(.wifiSSID) : nil,
                    wifiItem.content.password != nil ? .copy(.wifiPassword) : nil,
                    .shareLink,
                    isAutoFillExtension ? nil : .moveToTrash
                ]
                .compactMap { $0 }
            )
        case .raw:
            return nil
        }
    }

    func tagColors(for itemData: ItemData) -> [ItemTagColor] {
        guard let tagIds = itemData.tagIds, tagIds.isEmpty == false else {
            return []
        }
        return tagIds.compactMap { tagColorsByID[$0] }
    }

    func selectedItems(for itemIDs: [ItemID]) -> [ItemData] {
        guard itemIDs.isEmpty == false else { return [] }
        let selectedIDs = Set(itemIDs)
        var results: [ItemData] = []
        results.reserveCapacity(itemIDs.count)
        for list in listData.values {
            for item in list where selectedIDs.contains(item.id) {
                results.append(item)
            }
        }
        return results
    }

}
