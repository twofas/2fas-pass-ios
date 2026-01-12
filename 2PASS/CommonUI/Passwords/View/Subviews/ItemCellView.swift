// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let minimalCellHeight = 68.0
    static let maxTagIndicatorsCount = 3
    static let tagIndicatorBorderWidth: CGFloat = 2
    static let tagIndicatorTotalSize = ItemTagColorMetrics.small.size + tagIndicatorBorderWidth * 2
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
        button.tintColor = UIColor(resource: .labelSecondary)
        button.showsMenuAsPrimaryAction = true
        return button
    }()
    
    private lazy var tagIndicatorsView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = -Constants.tagIndicatorTotalSize * 0.35
        stack.isUserInteractionEnabled = false
        return stack
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
        state.isMenuButtonHidden = isMenuButtonHidden || state.isEditing
        return state
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        let resolvedBackgroundColor = setupBackground(with: state)
        setupContent(with: state, backgroundColor: resolvedBackgroundColor)
    }

    @discardableResult
    private func setupBackground(with state: UICellConfigurationState) -> UIColor {
        var config = defaultBackgroundConfiguration().updated(for: state)

        // Use neutral gray for selected state
        if state.isSelected {
            config.backgroundColor = UIColor(resource: .neutral100)
        }

        backgroundConfiguration = config
        return config.backgroundColor ?? .systemBackground
    }
    
    private func setupContent(with state: UICellConfigurationState, backgroundColor: UIColor) {
        guard let cellData = state.itemCellData else { return }

        var content = defaultContentConfiguration().updated(for: state)
        content.text = ItemNameFormatStyle().format(cellData.name)
        content.textProperties.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        content.textProperties.color = UIColor(resource: .mainText)
        content.textProperties.numberOfLines = 1

        if let secondaryText = cellData.description {
            content.secondaryText = secondaryText
            content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 15)
            content.secondaryTextProperties.color = UIColor(resource: .labelSecondary)
            content.secondaryTextProperties.numberOfLines = 1
        }

        content.directionalLayoutMargins = .zero
        content.directionalLayoutMargins.leading = Spacing.l + CGFloat(Config.iconDimension) + Spacing.m

        listContentView.configuration = content

        if let icon = state.loginIconImage {
            iconRenderer.updateIcon(with: icon)
        } else {
            iconRenderer.configure(with: cellData.iconType, name: cellData.name ?? "")
        }

        var accessories: [UICellAccessory] = []
        if state.isEditing {
            accessories.append(.multiselect())
            accessories.append(.customView(configuration: tagIndicatorsAccessoryConfiguration(for: cellData.tagColors, backgroundColor: backgroundColor)))
        } else {
            accessories.append(.customView(configuration: menuAccessoryConfiguration(for: cellData, isHidden: state.isMenuButtonHidden)))
        }

        self.accessories = accessories
    }

    func update(with cellData: ItemCellData) {
        guard self.cellData != cellData else { return }
        
        if self.cellData?.iconType.iconURL != cellData.iconType.iconURL {
            self.loginIconImage = nil
        }
        
        self.cellData = cellData
        
        setNeedsUpdateConfiguration()
    }
    
    func updateIcon(with iconData: Data, for cellData: ItemCellData) {
        guard self.cellData == cellData else { return }
        
        updateIcon(wirh: iconData)
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
        menuButton.frame.size = CGSize(width: 40, height: Constants.minimalCellHeight)
        
        let configuration = UICellAccessory.CustomViewConfiguration(
            customView: menuButton,
            placement: .trailing(),
            isHidden: isHidden,
            reservedLayoutWidth: .custom(40),
            maintainsFixedSize: true
        )

        return configuration
    }

    func tagIndicatorsAccessoryConfiguration(for colors: [ItemTagColor], backgroundColor: UIColor) -> UICellAccessory.CustomViewConfiguration {
        let limitedColors = Array(colors.prefix(Constants.maxTagIndicatorsCount))
        updateTagIndicators(with: limitedColors, backgroundColor: backgroundColor)
        let totalSize = Constants.tagIndicatorTotalSize
        let maxCount = CGFloat(Constants.maxTagIndicatorsCount)
        let reservedWidth = max(0, maxCount * totalSize + (maxCount - 1) * tagIndicatorsView.spacing)
        let visibleCount = CGFloat(limitedColors.count)
        let indicatorsWidth = visibleCount == 0 ? 0 : (visibleCount * totalSize + (visibleCount - 1) * tagIndicatorsView.spacing)
        tagIndicatorsView.frame = CGRect(
            x: max(0, (reservedWidth - indicatorsWidth) / 2),
            y: 0,
            width: indicatorsWidth,
            height: totalSize
        )

        return UICellAccessory.CustomViewConfiguration(
            customView: tagIndicatorsView,
            placement: .trailing(),
            reservedLayoutWidth: .custom(reservedWidth),
            maintainsFixedSize: true
        )
    }

    func updateTagIndicators(with colors: [ItemTagColor], backgroundColor: UIColor) {
        tagIndicatorsView.arrangedSubviews.forEach { view in
            tagIndicatorsView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let totalSize = Constants.tagIndicatorTotalSize
        let circleSize = ItemTagColorMetrics.small.size
        let limitedColors = Array(colors.prefix(Constants.maxTagIndicatorsCount))

        for (index, color) in limitedColors.enumerated() {
            // Outer container with background color (creates the "cut" effect)
            let containerView = UIView()
            containerView.backgroundColor = backgroundColor
            containerView.layer.cornerRadius = totalSize / 2
            containerView.layer.zPosition = CGFloat(limitedColors.count - index)
            containerView.translatesAutoresizingMaskIntoConstraints = false

            // Inner colored circle
            let circleView = UIView()
            circleView.backgroundColor = UIColor(color)
            circleView.layer.cornerRadius = circleSize / 2
            circleView.translatesAutoresizingMaskIntoConstraints = false

            containerView.addSubview(circleView)

            NSLayoutConstraint.activate([
                containerView.widthAnchor.constraint(equalToConstant: totalSize),
                containerView.heightAnchor.constraint(equalToConstant: totalSize),
                circleView.widthAnchor.constraint(equalToConstant: circleSize),
                circleView.heightAnchor.constraint(equalToConstant: circleSize),
                circleView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                circleView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])

            tagIndicatorsView.addArrangedSubview(containerView)
        }
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
                 .copy(.paymentCardNumber),
                 .copy(.paymentCardSecurityCode),
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
                        title: String(localized: .loginViewActionUrisTitle),
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
