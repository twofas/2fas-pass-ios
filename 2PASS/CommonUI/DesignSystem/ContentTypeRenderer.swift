// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let cornerRadius: CGFloat = 16
    static let innerIconDimension: CGFloat = 28
}

final class ContentTypeRenderer: UIView {

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .black
        return imageView
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
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true

        // Add icon image view
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)
        iconImageView.pinToParentCenter()

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: Constants.innerIconDimension),
            iconImageView.heightAnchor.constraint(equalToConstant: Constants.innerIconDimension)
        ])
    }

    func configure(with contentType: ItemContentType?) {
        guard let contentType else {
            iconImageView.image = nil
            return
        }
        
        backgroundColor = contentType.iconBackgroundColor
        iconImageView.image = contentType.icon

        if let iconColor = contentType.iconColor {
            iconImageView.tintColor = iconColor
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Config.iconDimension, height: Config.iconDimension)
    }
}
