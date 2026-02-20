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
    
    var selectedSort: SortType {
        interactor.currentSortType
    }
    
    var isAutoFillExtension: Bool {
        autoFillEnvironment != nil
    }
    
    var selectedFilterTag: ItemTagData? {
        didSet {
            view?.filterDidChange()
            reload()
        }
    }

    var selectedFilterProtectionLevel: ItemProtectionLevel? {
        didSet {
            view?.filterDidChange()
            reload()
        }
    }
    
    var showContentTypePicker: Bool {
        if let autoFillEnvironment {
            return autoFillEnvironment.isTextToInsert && hasItems
        } else {
            return hasItems
        }
    }
    
    private(set) var contentTypeFilter: ItemContentTypeFilter = .all
    
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
    private let notificationCenter: NotificationCenter
    private let toastPresenter: ToastPresenter
    private var listData: [Int: [ItemData]] = [:]
    private var tagColorsByID: [ItemTagID: ItemTagColor] = [:]
    private var isViewReady: Bool = false
    private var canLoadData: Bool {
        isViewReady && interactor.isUserLoggedIn
    }
    
    init(autoFillEnvironment: AutoFillEnvironment? = nil, flowController: PasswordsFlowControlling, interactor: PasswordsModuleInteracting) {
        self.autoFillEnvironment = autoFillEnvironment
        self.flowController = flowController
        self.interactor = interactor
        self.notificationCenter = .default
        self.toastPresenter = .shared
        self.iconsDataSource = RemoteImageCollectionDataSource(fetcher: IconFetcherProxy(interactor: interactor))

        notificationCenter.addObserver(self, selector: #selector(syncFinished), name: .webDAVStateChange, object: nil)
        notificationCenter.addObserver(self, selector: #selector(iCloudSyncFinished), name: .cloudStateChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(userLoggedIn), name: .userLoggedIn, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didImportItems), name: .didImportItems, object: nil)
        
        notificationCenter.addObserver(forName: .connectPullReqestDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension PasswordsPresenter {
    
    func viewWillAppear() {
        isViewReady = true
        refreshSelectedFilterTag()
        reload()
    }

    private func refreshSelectedFilterTag() {
        guard let selectedFilterTag else { return }

        if let tag = interactor.getTag(for: selectedFilterTag.tagID) {
            if tag != selectedFilterTag {
                self.selectedFilterTag = tag
            }
        } else {
            self.selectedFilterTag = nil
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
        reload()
    }
    
    func onSetSearchPhrase(_ searchPhrase: String?) {
        interactor.setSearchPhrase(searchPhrase)
        reload()
    }
    
    func onSetContentTypeFilter(_ filter: ItemContentTypeFilter) {
        view?.clearSelectionForContentTypeChange()
        contentTypeFilter = filter
        reload()
    }

    func onClearSearchPhrase() {
        interactor.setSearchPhrase(nil)
        
        Task { @MainActor in // fix animation
            reload()
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
        case .moveToTrash:
            Task { @MainActor in
                if await flowController.toConfirmDelete() {
                    interactor.moveToTrash(itemID)
                    reload()
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
            flowController.selectItem(id: itemData.id, contentType: itemData.contentType)
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
                itemIDs.forEach { interactor.moveToTrash($0) }
                view?.exitEditingMode()
                reload()
            }
        }
    }
    
    func normalizedURL(for uri: String) -> URL? {
        interactor.normalizedURL(for: uri)
    }
    
    func handleRefresh() {
        reload()
    }
    
    func listAllTags() -> [ItemTagData] {
        interactor.listAllTags()
    }

    func countPasswordsForTag(_ tagID: ItemTagID) -> Int {
        interactor.countItemsForTag(tagID)
    }

    func countPasswordsForProtectionLevel(_ protectionLevel: ItemProtectionLevel) -> Int {
        interactor.countItemsForProtectionLevel(protectionLevel)
    }
    
    func applyProtectionLevel(_ protectionLevel: ItemProtectionLevel, to itemIDs: [ItemID]) {
        do {
            try interactor.updateProtectionLevel(protectionLevel, for: itemIDs)
            view?.exitEditingMode()
            handleRefresh()
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
            handleRefresh()
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
    
    func reload() {
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

        if cellsCount == 0 {
            if interactor.isSearching || selectedFilterTag != nil || selectedFilterProtectionLevel != nil || (contentTypeFilter.contentType != nil && hasItems) {
                view?.showSearchEmptyScreen()
            } else {
                view?.showEmptyScreen()
            }
        } else {
            view?.showList()
        }
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

    @objc
    func syncFinished(_ event: Notification) {
        guard let e = event.userInfo?[Notification.webDAVState] as? WebDAVState, e == .synced else {
            return
        }
        DispatchQueue.main.async {
            self.reload()
        }
    }
    
    @objc
    func iCloudSyncFinished() {
        DispatchQueue.main.async {
            self.reload()
        }
    }
    
    @objc
    func userLoggedIn() {
        reload()
    }
    
    @objc
    func didImportItems() {
        Task { @MainActor in
            reload()
        }
    }
}
