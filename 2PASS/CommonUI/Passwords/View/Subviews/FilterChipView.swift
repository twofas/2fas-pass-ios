// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let colorDotSize: CGFloat = ItemTagColorMetrics.small.size
    static let iconSize: CGFloat = 16.0
}

final class FilterChipView: UIView {

    var onClose: (() -> Void)?

    private let containerView = UIView()
    private var glassEffectView: UIVisualEffectView?

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
        config.contentInsets = NSDirectionalEdgeInsets(top: Spacing.s, leading: Spacing.s, bottom: Spacing.s, trailing: Spacing.s)
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

        iconImageView.image = protectionLevel.uiIcon.withRenderingMode(.alwaysTemplate)
        iconImageView.tintColor = .accent
        nameLabel.text = protectionLevel.title

        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = containerView.bounds.height / 2
        containerView.layer.cornerRadius = cornerRadius
        glassEffectView?.layer.cornerRadius = cornerRadius
    }

    private func setupContainerView() {
        containerView.backgroundColor = UIColor(
            light: .black.withAlphaComponent(0.05),
            dark: .white.withAlphaComponent(0.15)
        )
        
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.pinToParent()
        
        if #available(iOS 26.0, *) {
            containerView.clipsToBounds = false
            clipsToBounds = false

            let effectView = UIVisualEffectView(effect: UIGlassEffect())
            containerView.insertSubview(effectView, at: 0)
            effectView.pinToParent()
            glassEffectView = effectView
        } else {
            containerView.clipsToBounds = true
        }
    }

    private func setupView(showColorDot: Bool) {
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        setupContainerView()

        containerView.addSubview(stackView, with: [
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Spacing.m),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        if showColorDot {
            stackView.addArrangedSubview(colorDotView)
        } else {
            stackView.addArrangedSubview(iconImageView)
        }
        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(closeButton)

        stackView.setCustomSpacing(0, after: nameLabel)

        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)

        NSLayoutConstraint.activate([
            colorDotView.widthAnchor.constraint(equalToConstant: Constants.colorDotSize),
            colorDotView.heightAnchor.constraint(equalToConstant: Constants.colorDotSize),
            iconImageView.widthAnchor.constraint(equalToConstant: Constants.iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: Constants.iconSize)
        ])
    }
}
