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
    
    let container = UIView()
    
    override func loadView() {
        layout = makeLayout()
        passwordsList = PasswordsListView(frame: .zero, collectionViewLayout: layout)
        
        self.view = passwordsList
        passwordsList?.configure(isAutoFillExtension: presenter.isAutoFillExtension)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = Asset.mainBackgroundColor.color
        
        setupContainer()
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
    
    func setupContainer() {
        view.addSubview(container, with: [
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.safeTopAnchor.constraint(equalTo: view.safeTopAnchor),
            container.safeBottomAnchor.constraint(equalTo: view.safeBottomAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
        container.isUserInteractionEnabled = false
    }
    
    func setupNavigationItems() {
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.largeTitleDisplayMode = .always
        title = T.homeTitle
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: UIImage(systemName: "plus.circle.fill"),
                style: .plain,
                target: self,
                action: #selector(addAction)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "list.bullet"),
                menu: sortMenu()
            )
        ]
        
        if presenter.isAutoFillExtension {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        }
    }
    
    func setupDelegates() {
        searchController.searchBarDelegate = self
        passwordsList?.delegate = self
    }
    
    func setupEmptyLists() {
        let emptySearchViewController = UIHostingController(rootView: EmptySearchView())
        placeChild(emptySearchViewController, container: container)
        emptySearchList = emptySearchViewController.view
        emptySearchList?.isHidden = true
        
        let emptyListViewController = UIHostingController(
            rootView: EmptyPasswordListView(onQuickSetup: { [weak self] in
                self?.presenter.onQuickSetup()
            })
            .quickSetupHidden(presenter.isAutoFillExtension)
        )
        placeChild(emptyListViewController, container: container)
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
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: AutoFillPasswordsSectionView.reuseIdentifier, for: indexPath) as? AutoFillPasswordsSectionView
            
            let passwordSection = self?.dataSource?.snapshot().sectionIdentifiers[indexPath.section] as? PasswordSectionData
            headerView?.titleLabel.text = passwordSection?.title
        
            return headerView
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
}

extension PasswordsViewController: CommonSearchDataSourceSearchable {
    func setSearchPhrase(_ phrase: String) {
        presenter.onSetSearchPhrase(phrase)
    }
    
    func clearSearchPhrase() {
        presenter.onClearSearchPhrase()
    }
}
