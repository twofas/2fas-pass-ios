// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

final class PasswordsViewController: UIViewController {
    var presenter: PasswordsPresenter!

    private let searchController = CommonSearchController()
    private var layout: UICollectionViewCompositionalLayout!
    private(set) var passwordsList: PasswordsListView?
    private(set) var dataSource: UICollectionViewDiffableDataSource<ItemSectionData, ItemCellData>?

    private(set) var emptyList: UIView?
    private(set) var emptySearchList: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Asset.mainBackgroundColor.color

        setupNavigationBar()
        setupPasswordsList()
        setupNavigationItems()
        setupDelegates()
        setupEmptyLists()
        setupDataSource()
    }
    
    // MARK: - App events
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        presenter.viewWillAppear()
        startSafeAreaKeyboardAdjustment()        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSafeAreaKeyboardAdjustment()
    }
    
    func updateNavigationBarButtons() {
        if #available(iOS 26, *) {
            let addButton = UIBarButtonItem(
                image: UIImage(systemName: "plus"),
                style: .plain,
                target: self,
                action: #selector(addAction)
            )

            addButton.tintColor = UIColor(hexString: "#007CF9", transparency: 0.8)
            addButton.style = .prominent

            let filterButton = UIBarButtonItem(
                image: UIImage(systemName: "line.3.horizontal.decrease"),
                menu: filterMenu()
            )
            filterButton.tintColor = presenter.selectedFilterTag != nil ? .brand500 : nil
            filterButton.style = presenter.selectedFilterTag != nil ? .prominent : .plain

            navigationItem.rightBarButtonItems = [
                addButton,
                .fixedSpace(0),
                filterButton
            ]
        } else {
            let filterIconName = presenter.selectedFilterTag != nil
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"

            let addButton = UIBarButtonItem(
                image: UIImage(systemName: "plus.circle.fill"),
                style: .plain,
                target: self,
                action: #selector(addAction)
            )

            navigationItem.rightBarButtonItems = [
                addButton,
                UIBarButtonItem(
                    image: UIImage(systemName: filterIconName),
                    menu: filterMenu()
                )
            ]
        }
    }
    
    func reloadLayout() {
        layout = makeLayout()
        passwordsList?.setCollectionViewLayout(layout, animated: true)
    }
}

private extension PasswordsViewController {
    
    @objc
    func addAction(sender: UIBarButtonItem) {
        presenter.onAdd(sourceItem: sender)
    }
    
    @objc
    func cancel() {
        presenter.onCancel()
    }
    
    func setupPasswordsList() {
        layout = makeLayout()
        let passwordsList = PasswordsListView(frame: .zero, collectionViewLayout: layout)
        self.passwordsList = passwordsList
        view.addSubview(passwordsList)
        passwordsList.pinToParent()
        passwordsList.configure(isAutoFillExtension: presenter.isAutoFillExtension)
    }

    func setupNavigationItems() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.largeTitleDisplayMode = .never
        title = T.homeTitle
        
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
        appearance.configureWithTransparentBackground()
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
            case ItemContentTypeFilterPickerView.elementKind:
                let pickerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: ItemContentTypeFilterPickerView.reuseIdentifier,
                    for: indexPath
                ) as? ItemContentTypeFilterPickerView
                
                pickerView?.onChange = { [weak self] filter in
                    self?.presenter.onSetContentTypeFilter(filter)
                }

                return pickerView
                
            case SelectedTagBannerView.elementKind:
                let bannerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: SelectedTagBannerView.reuseIdentifier,
                    for: indexPath
                ) as? SelectedTagBannerView
                
                if let selectedTag = self?.presenter.selectedFilterTag {
                    let itemCount = self?.presenter.countPasswordsForTag(selectedTag.tagID) ?? 0
                    bannerView?.configure(tagName: selectedTag.name, itemCount: itemCount)
                    bannerView?.onClear = { [weak self] in
                        self?.presenter.onClearFilterTag()
                        self?.updateLayoutWithTagFilter()
                    }
                }
                
                return bannerView
                
            case UICollectionView.elementKindSectionHeader:
                let headerView = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: AutoFillPasswordsSectionView.reuseIdentifier,
                    for: indexPath
                ) as? AutoFillPasswordsSectionView
                
                let passwordSection = self?.dataSource?.snapshot().sectionIdentifiers[indexPath.section] as? ItemSectionData
                headerView?.titleLabel.text = passwordSection?.title
                
                return headerView
            
            default:
                return nil
            }
        }
        
        presenter.onImageFetchResult = { [weak self] password, url, result in
            guard let dataSource = self?.dataSource else { return }
            
            switch result {
            case .success:
                var snapshot = dataSource.snapshot()
                snapshot.reconfigureItems([password])
                dataSource.apply(snapshot, animatingDifferences: false)
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
    
    func filterMenuItems() -> [UIMenuElement] {
        var menuItems: [UIMenuElement] = []
        menuItems.append(sortMenu())
        menuItems.append(tagMenu())
        
        // If a tag is selected, add a clear filter option at the end
        if presenter.selectedFilterTag != nil {
            let clearFilterAction = UIAction(
                title: T.loginFilterModalClear,
                attributes: .destructive
            ) { [weak self] _ in
                self?.presenter.onClearFilterTag()
                self?.updateLayoutWithTagFilter()
            }
            menuItems.append(clearFilterAction)
        }
        
        return menuItems
    }
    
    func tagMenu() -> UIMenu {
        let tags = presenter.listAllTags()
        
        // Create tag actions
        let tagActions = tags.map { tag in
            let count = presenter.countPasswordsForTag(tag.tagID)
            let title = "\(tag.name) (\(count))"
            return UIAction(
                title: title,
                state: presenter.selectedFilterTag?.tagID == tag.tagID ? .on : .off
            ) { [weak self] _ in
                self?.presenter.onSelectFilterTag(tag)
                self?.updateLayoutWithTagFilter()
            }
        }
        
        // Create a submenu that contains only tags (without "All" option)
        return UIMenu(
            title: T.loginFilterModalTag,
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            children: tagActions
        )
    }
    
    func sortMenu() -> UIMenu {
        UIMenu(
            title: T.loginFilterModalTitle,
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
    
    func updateLayoutWithTagFilter() {
        // Update navigation bar filter icon
        updateNavigationBarButtons()
        
        // Update the layout to show/hide the banner
        reloadLayout()
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
