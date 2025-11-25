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
            reload()
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
            view?.showContentTypeFilterPicker(hasItems)
        }
    }

    private let autoFillEnvironment: AutoFillEnvironment?
    private let iconsDataSource: RemoteImageCollectionDataSource<ItemCellData>
    private let flowController: PasswordsFlowControlling
    private let interactor: PasswordsModuleInteracting
    private let notificationCenter: NotificationCenter
    private let toastPresenter: ToastPresenter
    private var listData: [Int: [ItemData]] = [:]
    
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
        reload()
    }
    
    func onQuickSetup() {
        flowController.toQuickSetup()
    }
    
    func onAdd(sourceItem: (any UIPopoverPresentationControllerSourceItem)?) {
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
    
    func onCellMenuAction(_ action: PasswordCellMenu, itemID: ItemID, selectedURI: URL?) {
        switch action {
        case .view: flowController.toItemDetail(itemID: itemID)
        case .edit: flowController.toEditItem(itemID: itemID)
        case .copy(.loginUsername):
            if interactor.copyUsername(itemID) {
                toastPresenter.presentUsernameCopied()
            } else {
                toastPresenter.present(
                    T.passwordErrorCopyUsername,
                    style: .failure
                )
            }
        case .copy(.loginPassword):
            copyPassword(id: itemID)
            
        case .copy(.secureNoteText):
            copySecureNote(id: itemID)

        case .copy(.cardNumber):
            copyCardNumber(id: itemID)

        case .copy(.cardSecurityCode):
            copyCardSecurityCode(id: itemID)

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
            flowController.selectPassword(itemID: itemData.id)
        case .copy:
            switch itemData {
            case .login:
                copyPassword(id: itemData.id)
            case .secureNote:
                copySecureNote(id: itemData.id)
            case .card:
                copyCardNumber(id: itemData.id)
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
                T.passwordErrorCopyPassword,
                style: .failure
            )
        }
    }
    
    func copySecureNote(id: ItemID) {
        if interactor.copySecureNote(id) {
            toastPresenter.presentSecureNoteCopied()
        } else {
            toastPresenter.present(
                T.secureNoteErrorCopy,
                style: .failure
            )
        }
    }

    func copyCardNumber(id: ItemID) {
        if interactor.copyCardNumber(id) {
            toastPresenter.presentCardNumberCopied()
        } else {
            toastPresenter.present(
                T.cardErrorCopyNumber,
                style: .failure
            )
        }
    }

    func copyCardSecurityCode(id: ItemID) {
        if interactor.copyCardSecurityCode(id) {
            toastPresenter.presentCardSecurityCodeCopied()
        } else {
            toastPresenter.present(
                T.cardErrorCopySecurityCode,
                style: .failure
            )
        }
    }

    func item(at indexPath: IndexPath) -> ItemData? {
        listData[indexPath.section]?[safe: indexPath.item]
    }
    
    func reload() {
        listData.removeAll()
        hasSuggestedItems = false
        hasItems = interactor.hasItems
        
        let cellsCount: Int
        
        if let serviceIdentifiers = autoFillEnvironment?.serviceIdentifiers, interactor.isSearching == false {
            let list = interactor.loadList(forServiceIdentifiers: serviceIdentifiers, contentType: contentTypeFilter.contentType, tag: selectedFilterTag)
            
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
                let suggestedSection = ItemSectionData(title: T.commonSuggested)
                let section = ItemSectionData(title: T.commonOther)
                
                snapshot.appendSections([suggestedSection])
                snapshot.appendItems(suggestedCells, toSection: suggestedSection)
                snapshot.appendSections([section])
                snapshot.appendItems(restCells, toSection: section)
                
                cellsCount = suggestedCells.count + restCells.count
                itemsCount = cellsCount
            }
            
            view?.reloadData(newSnapshot: snapshot)
            
        } else {
            let list = interactor.loadList(contentType: contentTypeFilter.contentType, tag: selectedFilterTag)
            listData[0] = list
            let cells = list.compactMap(makeCellData(for:))
            let section = ItemSectionData()
            var snapshot = NSDiffableDataSourceSnapshot<ItemSectionData, ItemCellData>()
            snapshot.appendSections([section])
            snapshot.appendItems(cells, toSection: section)
        
            cellsCount = cells.count
            itemsCount = cellsCount
            
            view?.reloadData(newSnapshot: snapshot)
        }
        
        if cellsCount == 0 {
            if interactor.isSearching || selectedFilterTag != nil || (contentTypeFilter.contentType != nil && hasItems) {
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
                actions: [
                    .view,
                    .edit,
                    secureNoteItem.content.text != nil ? .copy(.secureNoteText) : nil,
                    isAutoFillExtension ? nil : .moveToTrash
                ]
                .compactMap { $0 }
            )
        case .card(let cardItem):
            let description: String? = if let mask = cardItem.content.cardNumberMask {
                CardNumberMaskFormatStyle().format(mask)
            } else {
                cardItem.content.cardHolder
            }
            return ItemCellData(
                itemID: cardItem.id,
                name: cardItem.name,
                description: description,
                iconType: .card(issuer: cardItem.content.cardIssuer),
                actions: [
                    .view,
                    .edit,
                    .copy(.cardNumber),
                    .copy(.cardSecurityCode),
                    isAutoFillExtension ? nil : .moveToTrash
                ]
                .compactMap { $0 }
            )
        case .raw:
            return nil
        }
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
        reload()
    }
}
