// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let minimalCellHeight = 68.0
}

class ItemCellView: UICollectionViewListCell {

    var menuAction: ((PasswordCellMenu, ItemID, URL?) -> Void)?
    var normalizeURI: (String) -> URL? = { _ in nil }

    private let iconRenderer = IconRenderer()
    private let listContentView = UIListContentView(configuration: .cell())

    private var cellData: ItemCellData?
    private var loginIconImage: UIImage?
    private var isMenuButtonHidden: Bool = false

    private lazy var menuButton: UIButton = {
        let button = UIButton()
        let config: UIImage.SymbolConfiguration = .init(font: UIFont.systemFont(ofSize: 22, weight: .medium))
        let image = UIImage(systemName: "ellipsis", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = Asset.labelSecondaryColor.color
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
        
    private func commonInit() {
        listContentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(listContentView)
        listContentView.pinToParent()
        
        iconRenderer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconRenderer)
        
        NSLayoutConstraint.activate([
            iconRenderer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.l),
            iconRenderer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconRenderer.widthAnchor.constraint(equalToConstant: CGFloat(Config.iconDimension)),
            iconRenderer.heightAnchor.constraint(equalToConstant: CGFloat(Config.iconDimension)),
        ])
    }
    
    override var configurationState: UICellConfigurationState {
        var state = super.configurationState
        state.itemCellData = cellData
        state.loginIconImage = loginIconImage
        state.isMenuButtonHidden = isMenuButtonHidden
        return state
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        setupContent(with: state)
        setupBackground(with: state)
    }
    
    private func setupBackground(with state: UICellConfigurationState) {
        backgroundConfiguration = defaultBackgroundConfiguration().updated(for: state)
    }
    
    private func setupContent(with state: UICellConfigurationState) {
        guard let cellData = state.itemCellData else { return }
        
        var content = defaultContentConfiguration().updated(for: state)
        content.text = ItemNameFormatStyle().format(cellData.name)
        content.textProperties.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        content.textProperties.color = Asset.mainTextColor.color
        content.textProperties.numberOfLines = 1

        if let secondaryText = cellData.description {
            content.secondaryText = secondaryText
            content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 15)
            content.secondaryTextProperties.color = Asset.labelSecondaryColor.color
            content.secondaryTextProperties.numberOfLines = 1
        }

        content.directionalLayoutMargins.leading = Spacing.l + CGFloat(Config.iconDimension) + Spacing.m

        listContentView.configuration = content

        if let icon = state.loginIconImage {
            iconRenderer.updateIcon(with: icon)
        } else {
            iconRenderer.configure(with: cellData.iconType, name: cellData.name ?? "")
        }

        accessories = [
            .customView(configuration: menuAccessoryConfiguration(for: cellData, isHidden: state.isMenuButtonHidden)),
        ]
    }

    func update(with cellData: ItemCellData) {
        guard self.cellData != cellData else { return }
        
        if self.cellData?.iconType.iconURL != cellData.iconType.iconURL {
            self.loginIconImage = nil
        }
        
        self.cellData = cellData
        
        setNeedsUpdateConfiguration()
    }

    func updateIcon(wirh iconData: Data) {
        guard let image = UIImage(data: iconData) else {
            return
        }
        self.loginIconImage = image
        setNeedsUpdateConfiguration()
    }

    func setMenuButtonHidden(_ hidden: Bool) {
        guard isMenuButtonHidden != hidden else { return }
        isMenuButtonHidden = hidden
        setNeedsUpdateConfiguration()
    }

    func menu(for cellData: ItemCellData) -> UIMenu {
        UIMenu(
            title: "",
            children: [UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.menuItems(for: cellData) ?? [])
            }]
        )
    }
}

private extension UIConfigurationStateCustomKey {
    static let itemCellData = UIConfigurationStateCustomKey("com.twofas.twopass.ItemCellData")
    static let loginIcon = UIConfigurationStateCustomKey("com.twofas.twopass.LoginIcon")
    static let isMenuButtonHidden = UIConfigurationStateCustomKey("com.twofas.twopass.IsMenuButtonHidden")
}

private extension UICellConfigurationState {
    var itemCellData: ItemCellData? {
        get { return self[.itemCellData] as? ItemCellData }
        set { self[.itemCellData] = newValue }
    }

    var loginIconImage: UIImage? {
        get { return self[.loginIcon] as? UIImage }
        set { self[.loginIcon] = newValue }
    }

    var isMenuButtonHidden: Bool {
        get { return self[.isMenuButtonHidden] as? Bool ?? false }
        set { self[.isMenuButtonHidden] = newValue }
    }
}

private extension ItemCellView {
    
    func menuAccessoryConfiguration(for cellData: ItemCellData, isHidden: Bool) -> UICellAccessory.CustomViewConfiguration {
        menuButton.menu = menu(for: cellData)

        let configuration = UICellAccessory.CustomViewConfiguration(
            customView: menuButton,
            placement: .trailing(),
            isHidden: isHidden,
            reservedLayoutWidth: .custom(40)
        )

        return configuration
    }

    func menuItems(for cellData: ItemCellData) -> [UIMenuElement] {
        var list: [UIMenuElement] = []

        for action in cellData.actions {
            switch action {
            case .view,
                 .edit,
                 .copy(.loginUsername),
                 .copy(.loginPassword),
                 .copy(.secureNoteText),
                 .moveToTrash:
                list.append(
                    UIAction(
                        title: action.label,
                        image: action.icon,
                        attributes: action.attributes
                    ) { [weak self] _ in
                        self?.menuAction?(action, cellData.itemID, nil)
                    }
                )
            case .goToURI(let uris):
                guard uris.isEmpty == false else { continue }
                list.append(
                    UIMenu(
                        title: T.loginViewActionUrisTitle,
                        image: action.icon,
                        children: [UIDeferredMenuElement.uncached { [weak self] completion in
                            completion(self?.urisSubmenu(for: uris, itemID: cellData.itemID) ?? [])
                        }]
                    )
                )
            }
        }
        
        return list
    }

    func urisSubmenu(for uris: [String], itemID: ItemID) -> [UIMenuElement] {
        uris.enumerated().map { index, url in
            UIAction(
                title: "\(url)"
            ) { [weak self] _ in
                guard let normalized = self?.normalizeURI(url) else { return }
                self?.menuAction?(.goToURI(uris: uris), itemID, normalized)
            }
        }
    }
}
