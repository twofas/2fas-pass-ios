// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

final class ItemListSectionView: UICollectionReusableView {
    static let reuseIdentifier = "ItemListSectionView"

    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
                
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Spacing.l),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Spacing.l),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Spacing.s)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
