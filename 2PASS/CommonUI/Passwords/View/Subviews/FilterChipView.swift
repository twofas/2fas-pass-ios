// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let colorDotSize: CGFloat = ItemTagColorMetrics.small.size
}

final class FilterChipView: UIView {

    var onClose: (() -> Void)?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.neutral200
        view.clipsToBounds = true
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Spacing.s
        return stack
    }()

    private let colorDotView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Constants.colorDotSize / 2
        view.clipsToBounds = true
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = UIColor.base1000
        return label
    }()

    private let closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 12)
        config.baseForegroundColor = .base1000
        config.contentInsets = .zero
        let button = UIButton(configuration: config)
        return button
    }()

    init(tag: ItemTagData) {
        super.init(frame: .zero)
        setupView(showColorDot: true)

        colorDotView.backgroundColor = UIColor(tag.color)
        nameLabel.text = tag.name
    }

    init(protectionLevel: ItemProtectionLevel) {
        super.init(frame: .zero)
        setupView(showColorDot: false)

        iconImageView.image = protectionLevel.uiIcon
        nameLabel.text = protectionLevel.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        
        containerView.layer.cornerRadius = containerView.bounds.height / 2
    }

    private func setupView(showColorDot: Bool) {
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        colorDotView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerView)
        containerView.addSubview(stackView)

        if showColorDot {
            stackView.addArrangedSubview(colorDotView)
        } else {
            stackView.addArrangedSubview(iconImageView)
        }
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(closeButton)

        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: Spacing.xs),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Spacing.m),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Spacing.m),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -Spacing.xs),

            colorDotView.widthAnchor.constraint(equalToConstant: Constants.colorDotSize),
            colorDotView.heightAnchor.constraint(equalToConstant: Constants.colorDotSize),

            iconImageView.widthAnchor.constraint(equalToConstant: Constants.colorDotSize),
            iconImageView.heightAnchor.constraint(equalToConstant: Constants.colorDotSize)
        ])
    }
}
