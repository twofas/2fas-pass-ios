// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

private struct Constants {
    static let maxSelectedTagBannerWidth: CGFloat = 500
    static let contentTypePickerHeight: CGFloat = 44
    static let searchTransitioningLayoutAnimationDuration = 0.3
    static let changeScrollContentInsetAnimationDuration = 0.3
    static let showSelectedTagBannerAnimationDuration = 0.15
}

final class PasswordsViewController: UIViewController {
    var presenter: PasswordsPresenter!

    private let searchController = CommonSearchController()
    private var layout: UICollectionViewCompositionalLayout!
    private(set) var passwordsList: PasswordsListView?
    private(set) var dataSource: UICollectionViewDiffableDataSource<ItemSectionData, ItemCellData>?

    private(set) var emptyList: UIView?
    private(set) var emptySearchList: UIView?
    
    var contentTypePicker: UIView? {
        contentTypePickerViewController?.view
    }
    
    private var isSearchTransitioning: Bool = false

    private let selectedTagBannerView = SelectedFilterView()

    private var contentTypePickerViewController: UIViewController?
    private var contentTypePickerTopConstraint: NSLayoutConstraint?
    private var contentTypePickerHeightConstraint: NSLayoutConstraint?
        
    private var edgeEffectView: UIView?
    private var edgeEffectToContentTypePickerConstraint: NSLayoutConstraint?
    private var edgeEffectToSelectedTagConstraint: NSLayoutConstraint?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Asset.mainBackgroundColor.color

        setupNavigationBar()
        setupPasswordsList()
        setupNavigationItems()
        setupDelegates()
        setupEmptyLists()
        setupDataSource()
        
        addContentTypePicker()
        
        if let contentTypePicker {
            addSelectedTagBanner(contentTypePicker: contentTypePicker)
            addTopEdgeEffect(contentTypePicker: contentTypePicker)
        }
        
        updateTagBanner()
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

        presenter.viewWillAppear()
        updateTagBanner()
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
    
    func reloadLayout() {
        view.layoutIfNeeded()

        let hasActiveFilter = presenter.selectedFilterTag != nil || presenter.selectedFilterProtectionLevel != nil
        UIView.animate(withDuration: Constants.changeScrollContentInsetAnimationDuration) {
            self.passwordsList?.contentInset.top = (hasActiveFilter ? self.selectedTagBannerView.frame.height + Spacing.m + (self.presenter.showContentTypePicker ? 0 : Spacing.l) : 0)
        }

        layout = makeLayout()
        passwordsList?.setCollectionViewLayout(layout, animated: true)
    }
    
    func setContentTypePickerOffset(_ offset: CGFloat) {
        let topOffset = offset + contentTypePickerTopOffset
        contentTypePickerTopConstraint?.constant = max(-(contentTypePicker?.frame.height ?? 0), topOffset)
        edgeEffectToContentTypePickerConstraint?.constant = max(-view.safeAreaInsets.top, offset)
    }
    
    func showContentTypeFilterPicker(_ flag: Bool) {
        contentTypePickerHeightConstraint?.constant = flag ? Constants.contentTypePickerHeight : 0
        contentTypePicker?.alpha = flag ? 1 : 0
        
        reloadLayout()
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
    
    func filterBarButton() -> UIBarButtonItem {
        let button = FilterButton()
        button.isFilterActive = presenter.selectedFilterTag != nil || presenter.selectedFilterProtectionLevel != nil
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
    
    func makeLayout() -> UICollectionViewCompositionalLayout {
        ItemListLayout(
            topInset: presenter.showContentTypePicker ? (contentTypePicker?.frame.height ?? 0) + Spacing.l : 0,
            showSectionHeaders: presenter.hasSuggestedItems
        )
    }
    
    func addContentTypePicker() {
        let filters = ItemContentTypeFilter.allKnown
        
        contentTypePickerViewController = UIHostingController(rootView: ItemContentTypePickerUIKitWrapper(
            initialFilter: filters[0],
            filters: filters,
            onChange: { [weak self] filter in
                self?.presenter.onSetContentTypeFilter(filter)
                self?.updateTagBanner()
                self?.reloadLayout()
            }
        ))
        
        guard let contentTypePicker else {
            return
        }
        
        contentTypePicker.translatesAutoresizingMaskIntoConstraints = false
        contentTypePicker.backgroundColor = .clear
        
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
    }
    
    func addSelectedTagBanner(contentTypePicker: UIView) {
        selectedTagBannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(selectedTagBannerView)

        let leading = selectedTagBannerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Spacing.l)
        leading.priority = .defaultHigh

        let trailing = selectedTagBannerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Spacing.l)
        trailing.priority = .defaultHigh

        let top = selectedTagBannerView.topAnchor.constraint(equalTo: contentTypePicker.bottomAnchor, constant: Spacing.l)
        top.priority = .defaultHigh
        NSLayoutConstraint.activate([
            selectedTagBannerView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: Spacing.m),
            top,
            leading,
            trailing,
            selectedTagBannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectedTagBannerView.widthAnchor.constraint(lessThanOrEqualToConstant: Constants.maxSelectedTagBannerWidth)
        ])

        selectedTagBannerView.onTagClose = { [weak self] _ in
            self?.presenter.onClearFilterTag()
            self?.didSelectedFilterChanged()
        }

        selectedTagBannerView.onProtectionLevelClose = { [weak self] _ in
            self?.presenter.onClearFilterProtectionLevel()
            self?.didSelectedFilterChanged()
        }

        didSelectedFilterChanged()
    }
    
    func addTopEdgeEffect(contentTypePicker: UIView) {
        if #available(iOS 26.0, *), let passwordsList {
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
    
    func setupPasswordsList() {
        layout = makeLayout()
        let passwordsList = PasswordsListView(frame: .zero, collectionViewLayout: layout)
        self.passwordsList = passwordsList
        view.addSubview(passwordsList)
        passwordsList.pinToParent()
        passwordsList.configure(isAutoFillExtension: presenter.isAutoFillExtension)
    }

    func setupNavigationItems() {
        searchController.delegate = self
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
    
    func filterMenuItems() -> [UIMenuElement] {
        var menuItems: [UIMenuElement] = []
        menuItems.append(sortMenu())
        menuItems.append(tagMenu())
        return menuItems
    }
    
    func tagMenu() -> UIMenu {
        // Create protection level actions
        let protectionLevelActions = ItemProtectionLevel.allCases.map { level in
            let count = presenter.countPasswordsForProtectionLevel(level)
            let title = "\(level.title) (\(count))"
            return UIAction(
                title: title,
                image: level.uiIcon.withTintColor(.accent),
                state: presenter.selectedFilterProtectionLevel == level ? .on : .off
            ) { [weak self] _ in
                self?.presenter.onSelectFilterProtectionLevel(level)
                self?.didSelectedFilterChanged()
            }
        }

        let tags = presenter.listAllTags()

        // Create tag actions
        let tagActions: [UIMenuElement]
        if tags.isEmpty {
            let addTagAction = UIAction(
                title: T.tagsAddNewCta,
                image: UIImage(systemName: "plus")
            ) { [weak self] _ in
                self?.presenter.onAddTag()
            }
            tagActions = [addTagAction]
        } else {
            tagActions = tags.map { tag in
                let count = presenter.countPasswordsForTag(tag.tagID)
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
                    self?.didSelectedFilterChanged()
                }
            }
        }

        // Create inline menu with protection levels, separator, and tags
        let protectionLevelSection = UIMenu(title: "", options: .displayInline, children: protectionLevelActions)
        let tagSection = UIMenu(title: "", options: .displayInline, children: tagActions)

        return UIMenu(
            title: T.loginFilterModalTag,
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            children: [protectionLevelSection, tagSection]
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
    
    func updateTagBanner() {
        if let selectedTag = presenter.selectedFilterTag {
            selectedTagBannerView.setTag(selectedTag)
        } else {
            selectedTagBannerView.setTag(nil)
        }

        if let selectedProtectionLevel = presenter.selectedFilterProtectionLevel {
            selectedTagBannerView.setProtectionLevel(selectedProtectionLevel)
        } else {
            selectedTagBannerView.setProtectionLevel(nil)
        }

        let hasActiveFilter = presenter.selectedFilterTag != nil || presenter.selectedFilterProtectionLevel != nil
        edgeEffectToContentTypePickerConstraint?.isActive = !hasActiveFilter
        edgeEffectToSelectedTagConstraint?.isActive = hasActiveFilter

        if hasActiveFilter {
            UIView.animate(withDuration: Constants.showSelectedTagBannerAnimationDuration) {
                self.selectedTagBannerView.alpha = 1
            }
        } else {
            self.selectedTagBannerView.alpha = 0
        }
    }

    func didSelectedFilterChanged() {
        updateTagBanner()
        updateNavigationBarButtons()
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

