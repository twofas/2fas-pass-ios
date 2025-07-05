// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let menuButtonWidth: CGFloat = 40
    static let separatorHeight: CGFloat = 0.5
    static let separatorLeadingPadding: CGFloat = 66
    static let menuButtonHorizontalOffset: CGFloat = 6.0
}

class PasswordsCellView: UICollectionViewCell {
    static let reuseIdentifier = "PasswordsCellView"
    
    fileprivate class var menuOptions: [PasswordCellMenu] {
        PasswordCellMenu.allCases
    }
    
    var menuAction: ((PasswordCellMenu, PasswordID, URL?) -> Void)?
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = Asset.mainTextColor.color
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.showsExpansionTextWhenTruncated = true
        label.allowsDefaultTighteningForTruncation = true
        label.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        return label
    }()
    
    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = Asset.labelSecondaryColor.color
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.showsExpansionTextWhenTruncated = true
        label.allowsDefaultTighteningForTruncation = true
        label.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        return label
    }()
    
    private let mainContainer = UIView()
    private let iconContainer = UIView()
    private let textContainer = UIStackView()
    
    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .neutral200
        v.isUserInteractionEnabled = false
        return v
    }()
    
    private let menuButton: UIButton = {
        let button = UIButton()
        let config: UIImage.SymbolConfiguration = .init(font: UIFont.systemFont(ofSize: 22, weight: .medium))
        let image = UIImage(systemName: "ellipsis", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = Asset.labelSecondaryColor.color
        return button
    }()
    
    private let iconRenderer = IconRenderer()
    
    private var passwordID: PasswordID?
    private var hasUsername = false
    private var hasPassword = false
    private var uris: [String] = []
    private var normalizeURI: (String) -> URL? = { URL(string: $0) }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        setupBackground()
        setupLayout()
        
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = menu()
        
        iconContainer.addSubview(iconRenderer)
        iconRenderer.pinToParentCenter()
    }
    
    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? .neutral100 : Asset.mainBackgroundColor.color
        }
    }
    
    func update(
        cellData: PasswordCellData
    ) {
        nameLabel.text = ItemNameFormatStyle().format(cellData.name)
        usernameLabel.text = cellData.username
        self.passwordID = cellData.passwordID
        self.hasUsername = cellData.hasUsername
        self.hasPassword = cellData.hasPassword
        self.uris = cellData.uris
        self.normalizeURI = cellData.normalizeURI
        iconRenderer.configure(with: cellData.iconType, name: cellData.name ?? "")
    }
    
    func updateIcon(wirh iconData: Data) {
        iconRenderer.updateIcon(with: iconData)
    }
}

private extension PasswordsCellView {
    func setupBackground() {
        contentView.backgroundColor = Asset.mainBackgroundColor.color
        backgroundColor = Asset.mainBackgroundColor.color
    }
    
    func setupLayout() {
        contentView.addSubview(mainContainer, with: [
            mainContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Spacing.l),
            mainContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Spacing.l + Constants.menuButtonHorizontalOffset),
            mainContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Spacing.l),
            mainContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Spacing.l)
        ])
                
        mainContainer.addSubview(iconContainer, with: [
            iconContainer.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            iconContainer.centerYAnchor.constraint(equalTo: mainContainer.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: CGFloat(Config.iconDimension)),
            iconContainer.heightAnchor.constraint(equalToConstant: CGFloat(Config.iconDimension)),
            iconContainer.topAnchor.constraint(greaterThanOrEqualTo: mainContainer.topAnchor),
            iconContainer.bottomAnchor.constraint(lessThanOrEqualTo: mainContainer.bottomAnchor)
        ])
                
        mainContainer.addSubview(textContainer, with: [
            textContainer.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: Spacing.m),
            textContainer.centerYAnchor.constraint(equalTo: mainContainer.centerYAnchor),
            textContainer.topAnchor.constraint(greaterThanOrEqualTo: mainContainer.topAnchor),
            textContainer.bottomAnchor.constraint(lessThanOrEqualTo: mainContainer.bottomAnchor)
        ])

        textContainer.axis = .vertical
        textContainer.spacing = Spacing.xxs
        textContainer.addArrangedSubview(nameLabel)
        textContainer.addArrangedSubview(usernameLabel)
        
        mainContainer.addSubview(menuButton, with: [
            menuButton.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            menuButton.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor),
            menuButton.leadingAnchor.constraint(equalTo: textContainer.trailingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: Constants.menuButtonWidth)
        ])
        
        addSubview(separator, with: [
            separator.heightAnchor.constraint(equalToConstant: Constants.separatorHeight),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.separatorLeadingPadding),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func menu() -> UIMenu {
        UIMenu(
            title: "",
            children: [UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.menuItems() ?? [])
            }]
        )
    }
    
    func menuItems() -> [UIMenuElement] {
        var list: [UIMenuElement] = []
        
        if Self.menuOptions.contains(.view) {
            list.append(
                UIAction(
                    title: PasswordCellMenu.view.label,
                    image: PasswordCellMenu.view.icon
                ) { [weak self] _ in
                    guard let self, let passwordID else { return }
                    menuAction?(.view, passwordID, nil)
                }
            )
        }
        
        if Self.menuOptions.contains(.edit) {
            list.append(
                UIAction(
                    title: PasswordCellMenu.edit.label,
                    image: PasswordCellMenu.edit.icon
                ) { [weak self] _ in
                    guard let self, let passwordID else { return }
                    menuAction?(.edit, passwordID, nil)
                }
            )
        }
        
        if hasUsername, Self.menuOptions.contains(.copyUsername) {
            list.append(
                UIAction(
                    title: PasswordCellMenu.copyUsername.label,
                    image: PasswordCellMenu.copyUsername.icon
                ) { [weak self] _ in
                    guard let self, let passwordID else { return }
                    menuAction?(.copyUsername, passwordID, nil)
                }
            )
        }
        if hasPassword, Self.menuOptions.contains(.copyPassword) {
            list.append(
                UIAction(
                    title: PasswordCellMenu.copyPassword.label,
                    image: PasswordCellMenu.copyPassword.icon
                ) { [weak self] _ in
                    guard let self, let passwordID else { return }
                    menuAction?(.copyPassword, passwordID, nil)
                }
            )
        }
        
        if !uris.isEmpty, Self.menuOptions.contains(.goToURI) {
            list.append(
                UIMenu(
                    title: T.loginViewActionUrisTitle,
                    children: [UIDeferredMenuElement.uncached { [weak self] completion in
                        completion(self?.urisSubmenu() ?? [])
                    }]
                )
            )
        }
        
        if Self.menuOptions.contains(.moveToTrash) {
            list.append(
                UIAction(
                    title: PasswordCellMenu.moveToTrash.label,
                    image: PasswordCellMenu.moveToTrash.icon,
                    attributes: PasswordCellMenu.moveToTrash.attributes
                ) { [weak self] _ in
                    guard let self, let passwordID else { return }
                    menuAction?(.moveToTrash, passwordID, nil)
                }
            )
        }
        
        return list
    }
    
    func urisSubmenu() -> [UIMenuElement] {
        uris.enumerated().map { index, url in
            UIAction(
                title: "\(url)"
            ) { [weak self] _ in
                guard let self, let passwordID, let normalized = normalizeURI(url) else { return }
                menuAction?(.goToURI, passwordID, normalized)
            }
        }
    }
}

final class MainAppPasswordsCellView: PasswordsCellView {
}

final class AutoFillPasswordsCellView: PasswordsCellView {

    override class var menuOptions: [PasswordCellMenu] {
        super.menuOptions.filter {
            $0 != .goToURI && $0 != .moveToTrash
        }
    }
}
