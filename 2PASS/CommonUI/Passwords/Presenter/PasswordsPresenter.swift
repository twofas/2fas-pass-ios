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
    
    private(set) var itemsCount: Int = 0
    private(set) var hasSuggestedItems = false

    private let autoFillEnvironment: AutoFillEnvironment?
    private let iconsDataSource: RemoteImageCollectionDataSource<PasswordCellData>
    private let flowController: PasswordsFlowControlling
    private let interactor: PasswordsModuleInteracting
    private let notificationCenter: NotificationCenter
    private let toastPresenter: ToastPresenter
    private var listData: [Int: [PasswordData]] = [:]
    
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
    
    func onAdd() {
        if interactor.canAddPassword {
            flowController.toAddPassword()
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
    
    func onCellMenuAction(_ action: PasswordCellMenu, passwordID: PasswordID, selectedURI: URL?) {
        switch action {
        case .view: flowController.toViewPassword(passwordID: passwordID)
        case .edit: flowController.toEditPassword(passwordID: passwordID)
        case .copyUsername:
            if interactor.copyUsername(passwordID) {
                toastPresenter.presentUsernameCopied()
            } else {
                toastPresenter.present(
                    T.passwordErrorCopyUsername,
                    style: .info
                )
            }
        case .copyPassword:
            copyPassword(id: passwordID)
            
        case .goToURI: if let selectedURI {
            flowController.toURI(selectedURI)
        }
        case .moveToTrash:
            Task { @MainActor in
                if await flowController.toConfirmDelete() {
                    interactor.moveToTrash(passwordID)
                    reload()
                }
            }
        }
    }
    
    func onDidSelectAt(_ indexPath: IndexPath) {
        guard let passwordData = item(at: indexPath) else {
            return
        }
        
        switch interactor.selectAction {
        case .viewDetails:
            flowController.selectPassword(passwordID: passwordData.passwordID)
        case .copyPassword:
            copyPassword(id: passwordData.passwordID)
        case .goToURI:
            if let uri = passwordData.uris?.first, let normalized = interactor.normalizedURL(for: uri.uri) {
                flowController.toURI(normalized)
            }
        case .edit:
            flowController.toEditPassword(passwordID: passwordData.passwordID)
        }
    }
    
    func handleRefresh() {
        reload()
    }
    
    func listAllTags() -> [ItemTagData] {
        interactor.listAllTags()
    }

    func countPasswordsForTag(_ tagID: ItemTagID) -> Int {
        interactor.countPasswordsForTag(tagID)
    }
}

extension PasswordsPresenter {

    @MainActor
    var onImageFetchResult: (PasswordCellData, URL, Result<Data, Error>) -> Void {
        get { iconsDataSource.onImageFetchResult }
        set { iconsDataSource.onImageFetchResult = newValue }
    }
    
    @MainActor
    func cachedImage(from url: URL) -> Data? {
        iconsDataSource.cachedImage(from: url)
    }
    
    @MainActor
    func fetchImage(from url: URL, for password: PasswordCellData) {
        iconsDataSource.fetchImage(from: url, for: password)
    }
    
    @MainActor
    func cancelFetches(for password: PasswordCellData) {
        iconsDataSource.cancelFetches(for: password)
    }
}

private extension PasswordsPresenter {
    
    func copyPassword(id: PasswordID) {
        if interactor.copyPassword(id) {
            toastPresenter.presentPasswordCopied()
        } else {
            toastPresenter.present(
                T.passwordErrorCopyPassword,
                style: .failure
            )
        }
    }
    
    func item(at indexPath: IndexPath) -> PasswordData? {
        listData[indexPath.section]?[safe: indexPath.item]
    }
    
    func reload() {
        listData.removeAll()
        hasSuggestedItems = false
        
        let cellsCount: Int
        
        if let serviceIdentifiers = autoFillEnvironment?.serviceIdentifiers, interactor.isSearching == false {
            let list = interactor.loadList(forServiceIdentifiers: serviceIdentifiers, tag: selectedFilterTag)
            
            var snapshot = NSDiffableDataSourceSnapshot<PasswordSectionData, PasswordCellData>()
            
            if list.suggested.isEmpty {
                listData[0] = list.rest
                
                let restCells = list.rest.map(makeCellData(for:))
                let section = PasswordSectionData()
                
                snapshot.appendSections([section])
                snapshot.appendItems(restCells, toSection: section)
                
                cellsCount = list.rest.count
                itemsCount = cellsCount
                
            } else {
                listData[0] = list.suggested
                listData[1] = list.rest
                hasSuggestedItems = true

                let suggestedCells = list.suggested.map(makeCellData(for:))
                let restCells = list.rest.map(makeCellData(for:))
                let suggestedSection = PasswordSectionData(title: T.commonSuggested)
                let section = PasswordSectionData(title: T.commonOther)
                
                snapshot.appendSections([suggestedSection])
                snapshot.appendItems(suggestedCells, toSection: suggestedSection)
                snapshot.appendSections([section])
                snapshot.appendItems(restCells, toSection: section)
                
                cellsCount = suggestedCells.count + restCells.count
                itemsCount = cellsCount
            }
            
            view?.reloadData(newSnapshot: snapshot)
            
        } else {
            let list = interactor.loadList(tag: selectedFilterTag)
            listData[0] = list
            let cells = list.map(makeCellData(for:))
            let section = PasswordSectionData()
            var snapshot = NSDiffableDataSourceSnapshot<PasswordSectionData, PasswordCellData>()
            snapshot.appendSections([section])
            snapshot.appendItems(cells, toSection: section)
        
            cellsCount = cells.count
            itemsCount = cellsCount
            
            view?.reloadData(newSnapshot: snapshot)
        }
        
        if cellsCount == 0 {
            if interactor.isSearching || selectedFilterTag != nil {
                view?.showSearchEmptyScreen()
            } else {
                view?.showEmptyScreen()
            }
        } else {
            view?.showList()
        }
    }
    
    func makeCellData(for password: PasswordData) -> PasswordCellData {
        PasswordCellData(
            passwordID: password.passwordID,
            name: password.name,
            username: password.username,
            iconType: password.iconType,
            hasUsername: password.username != nil && password.username?.isEmpty == false,
            hasPassword: password.password != nil,
            uris: password.uris?.map { $0.uri } ?? [],
            normalizeURI: { [weak self] uri in
                guard let interactor = self?.interactor else { return nil }
                return interactor.normalizedURL(for: uri)
            }
        )
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
