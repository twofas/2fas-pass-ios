// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

final class SelectedTagBannerView: UICollectionReusableView {
    static let reuseIdentifier = "SelectedTagBannerView"
    
    private let containerView = UIView()
    private let filterIconImageView = UIImageView()
    private let messageLabel = UILabel()
    private let clearButton = UIButton(type: .system)
    
    var onClear: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = Asset.backroundSecondary.color
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        // Add container
        addSubview(containerView, with: [
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.s),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.s),
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: Spacing.s),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Spacing.s)
        ])
        
        // Setup filter icon
        filterIconImageView.image = UIImage(systemName: "line.3.horizontal.decrease.circle")
        filterIconImageView.tintColor = Asset.mainTextColor.color
        filterIconImageView.contentMode = .scaleAspectFit
        
        // Setup message label with attributed text
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = Asset.mainTextColor.color
        messageLabel.numberOfLines = 2
        messageLabel.lineBreakMode = .byWordWrapping
        
        // Setup clear button
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        clearButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        clearButton.tintColor = Asset.labelSecondaryColor.color
        clearButton.addTarget(self, action: #selector(clearButtonTapped), for: .touchUpInside)
        
        // Create horizontal stack for content
        let contentStackView = UIStackView(arrangedSubviews: [filterIconImageView, messageLabel])
        contentStackView.axis = .horizontal
        contentStackView.spacing = 6
        contentStackView.alignment = .center
        
        // Add constraints for icon size
        NSLayoutConstraint.activate([
            filterIconImageView.widthAnchor.constraint(equalToConstant: 22),
            filterIconImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
        
        // Add constraints for clear button size
        NSLayoutConstraint.activate([
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Add elements to container
        containerView.addSubview(contentStackView, with: [
            contentStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
        
        containerView.addSubview(clearButton, with: [
            clearButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            clearButton.leadingAnchor.constraint(greaterThanOrEqualTo: contentStackView.trailingAnchor, constant: 8)
        ])
    }
    
    func configure(tagName: String, itemCount: Int) {
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "Showing \(itemCount) items tagged: ", attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: Asset.mainTextColor.color
        ]))
        text.append(NSAttributedString(string: tagName, attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: Asset.mainTextColor.color
        ]))
        messageLabel.attributedText = text
    }
    
    @objc private func clearButtonTapped() {
        onClear?()
    }
}
