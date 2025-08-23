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
    private(set) var dataSource: UICollectionViewDiffableDataSource<PasswordSectionData, PasswordCellData>?
    
    private(set) var emptyList: UIView?
    private(set) var emptySearchList: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Asset.mainBackgroundColor.color

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
}

private extension PasswordsViewController {
    @objc
    func addAction() {  
        presenter.onAdd()
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
        navigationItem.largeTitleDisplayMode = .always
        title = T.homeTitle
        
        updateNavigationBarButtons()
        
        if presenter.isAutoFillExtension {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        }
    }
    
    func updateNavigationBarButtons() {
        let filterIconName = presenter.selectedFilterTag != nil 
            ? "line.3.horizontal.decrease.circle.fill" 
            : "line.3.horizontal.decrease.circle"
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "plus.circle.fill"),
                style: .plain,
                target: self,
                action: #selector(addAction)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: filterIconName),
                menu: tagFilterMenu()
            )
        ]
    }
    
    func setupDelegates() {
        searchController.searchBarDelegate = self
        passwordsList?.delegate = self
    }
    
    func setupEmptyLists() {
        let emptySearchViewController = UIHostingController(rootView: EmptySearchView())
        addChild(emptySearchViewController)
        view.addSubview(emptySearchViewController.view)
        emptySearchViewController.view?.pinToSafeAreaParentCenter()
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
        emptyListViewController.view?.pinToSafeAreaParentCenter()
        emptyListViewController.didMove(toParent: self)
        
        emptyList = emptyListViewController.view
        emptyList?.isHidden = true
    }
    
    func setupDataSource() {
        guard let passwordsList else { return }
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: passwordsList,
            cellProvider: { [weak self] collectionView, indexPath, item -> UICollectionViewCell? in
                self?.getCell(for: collectionView, indexPath: indexPath, item: item)
            })
        
        dataSource?.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            switch kind {
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
                
                let passwordSection = self?.dataSource?.snapshot().sectionIdentifiers[indexPath.section] as? PasswordSectionData
                headerView?.titleLabel.text = passwordSection?.title
                
                return headerView
            
            default:
                return nil
            }
        }
        
        presenter.onImageFetchResult = { [weak self] password, url, result in
            guard let indexPath = self?.dataSource?.indexPath(for: password) else { return }
            guard let cell = self?.passwordsList?.cellForItem(at: indexPath) as? PasswordsCellView else { return }
            
            switch result {
            case .success(let data):
                cell.updateIcon(wirh: data)
            case .failure:
                break
            }
        }
    }
    
    func tagFilterMenu() -> UIMenu {
        UIMenu(
            children: [UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.tagFilterMenuItems() ?? [])
            }]
        )
    }
    
    func tagFilterMenuItems() -> [UIMenuElement] {
        // Get all available tags
        let tags = presenter.listAllTags()
        
        var menuItems: [UIMenuElement] = []
        
        // Add Sort submenu first
        let sortActions = SortType.allCases.map { sortType in
            UIAction(
                title: sortType.label,
                image: sortType.icon,
                state: presenter.selectedSort == sortType ? .on : .off
            ) { [weak self] _ in
                self?.presenter.onSelectSort(sortType)
            }
        }
        
        let sortSubmenu = UIMenu(
            title: "Sort by",
            image: UIImage(systemName: "arrow.up.arrow.down"),
            children: sortActions
        )
        menuItems.append(sortSubmenu)
        
        // Add "All" option for tags
        let allAction = UIAction(
            title: "All (\(presenter.itemsCount))",
            state: presenter.selectedFilterTag == nil ? .on : .off
        ) { [weak self] _ in
            self?.presenter.onClearFilterTag()
            self?.updateLayoutWithTagFilter()
        }
        
        // If there are tags, create a submenu for them
        if !tags.isEmpty {
            // Create tag actions
            let tagActions = tags.sorted(by: { $0.name < $1.name }).map { tag in
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
            
            // Create a submenu that contains all tags
            let tagsSubmenu = UIMenu(
                title: "Filter",
                image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
                children: [allAction] + tagActions
            )
            menuItems.append(tagsSubmenu)
        } else {
            menuItems.append(allAction)
        }
        
        // If a tag is selected, add a clear filter option at the end
        if presenter.selectedFilterTag != nil {
            let clearFilterAction = UIAction(
                title: "Clear filters",
                attributes: .destructive
            ) { [weak self] _ in
                self?.presenter.onClearFilterTag()
                self?.updateLayoutWithTagFilter()
            }
            menuItems.append(clearFilterAction)
        }
        
        return menuItems
    }
    
    func sortMenu() -> UIMenu {
        UIMenu(
            title: T.loginFilterModalTitle,
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
        layout = makeLayout()
        passwordsList?.setCollectionViewLayout(layout, animated: true)
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
