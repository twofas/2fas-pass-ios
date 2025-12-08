// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

final class SelectedTagBannerView: UICollectionReusableView {
    static let reuseIdentifier = "SelectedTagBannerView"
    static let elementKind = "SelectedTagBanner"
    
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
        
        messageLabel.textColor = Asset.mainTextColor.color
        messageLabel.numberOfLines = 2
        
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
            contentStackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        
        containerView.addSubview(clearButton, with: [
            clearButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            clearButton.leadingAnchor.constraint(greaterThanOrEqualTo: contentStackView.trailingAnchor, constant: 8)
        ])        
    }
    
    func configure(tagName: String, itemCount: Int) {
        do {
            var attributedString = try AttributedString(markdown: T.filterTagBannerIos(itemCount, tagName))
            attributedString.font = .preferredFont(forTextStyle: .subheadline)
            attributedString.foregroundColor = Asset.mainTextColor.color
            messageLabel.attributedText = NSAttributedString(attributedString)
        } catch {
            messageLabel.text = T.filterTagBannerIos(itemCount, tagName)
            messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        }
    }
    
    @objc private func clearButtonTapped() {
        onClear?()
    }
}
