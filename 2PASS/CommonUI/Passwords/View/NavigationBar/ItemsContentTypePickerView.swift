// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

struct ItemsContentTypePickerOption {
    let contentType: ItemContentTypeFilter
    let count: Int
}

class ItemsContentTypePickerView: UIView {

    var options: (() -> [ItemsContentTypePickerOption]) = { [] }
    
    var selectedContentType: ItemContentTypeFilter = .all {
        didSet {
            switch selectedContentType {
            case .all:
                updateSelectionForAllItems()
            case .contentType(.login):
                updateSelection(title: "Logins", icon: "person.crop.square.fill", color: UIColor(hexString: "#00C700")!)
            case .contentType(.notes):
                updateSelection(title: "Notes", icon: "note.text", color: UIColor(hexString: "#FF8400")!)
            }
        }
    }
    
    var onChange: ((ItemContentTypeFilter) -> Void)?
    
    enum SizeMode {
        case largeTitle
        case inline
    }
    
    private let containerStack = UIStackView()
    private let iconView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronImageView = UIImageView()
    private let tapButton = UIButton()
    private let sizeMode: SizeMode
    
    init(sizeMode: SizeMode = .largeTitle) {
        self.sizeMode = sizeMode
        super.init(frame: .zero)
        setupViews()
        setupMenu()
    }
    
    override init(frame: CGRect) {
        self.sizeMode = .largeTitle
        super.init(frame: frame)
        setupViews()
        setupMenu()
    }
    
    private func setupViews() {
        // Size-dependent values
        let iconSize: CGFloat = sizeMode == .largeTitle ? 40 : 30
        let iconImageSize: CGFloat = sizeMode == .largeTitle ? 20 : 16
        let font: UIFont = sizeMode == .largeTitle ? .largeTitleEmphasized : .headlineEmphasized
        let iconCornerRadius: CGFloat = sizeMode == .largeTitle ? 12 : 8
        let chevronSize: CGFloat = sizeMode == .largeTitle ? 20 : 14
        let stackSpacing: CGFloat = sizeMode == .largeTitle ? 8 : 6
        
        // Icon container with blue background
        iconView.layer.cornerRadius = iconCornerRadius
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon image
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconView.addSubview(iconImageView)
        
        // Title label
        titleLabel.font = font
        titleLabel.textColor = .base1000
        
        // Chevron
        let chevronConfig = UIImage.SymbolConfiguration(pointSize: chevronSize, weight: .bold)
        chevronImageView.image = UIImage(systemName: "chevron.down", withConfiguration: chevronConfig)
        chevronImageView.tintColor = .base1000
        
        // Stack view setup
        containerStack.axis = .horizontal
        containerStack.alignment = .center
        containerStack.spacing = stackSpacing
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        
        containerStack.addArrangedSubview(iconView)
        containerStack.addArrangedSubview(titleLabel)
        containerStack.addArrangedSubview(chevronImageView)
        
        addSubview(containerStack)
        
        // Transparent button overlay for tap handling
        tapButton.backgroundColor = .clear
        tapButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tapButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            // Icon view
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            
            // Icon image inside icon view
            iconImageView.widthAnchor.constraint(equalToConstant: iconImageSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconImageSize),
            iconImageView.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            
            // Container stack
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerStack.topAnchor.constraint(equalTo: topAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Tap button overlay
            tapButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            tapButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            tapButton.topAnchor.constraint(equalTo: topAnchor),
            tapButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        updateSelectionForAllItems()
    }
    
    private func setupMenu() {
        let menu = UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
            completion(
                self?.options().map { option in
                    UIAction(title: "\(option.contentType.title) (\(option.count))") { [weak self] _ in
                        self?.selectedContentType = option.contentType
                        self?.onChange?(option.contentType)
                    }
                } ?? []
            )
        }])
        tapButton.menu = menu
        tapButton.showsMenuAsPrimaryAction = true
    }
    
    private func updateSelectionForAllItems() {
        updateSelection(title: ItemContentTypeFilter.all.title, icon: "tray.full.fill", color: UIColor.brand500)
    }
    
    private func updateSelection(title: String, icon: String, color: UIColor) {
        titleLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
        iconView.backgroundColor = color
    }
    
    @MainActor required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
