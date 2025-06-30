// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

final class AutoFillPasswordsSectionView: UICollectionReusableView {
    static let reuseIdentifier = "PasswordsHeaderView"

    let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = Asset.mainBackgroundColor.color
        addSubview(titleLabel)
        titleLabel.pinToParent(with: .init(top: 0, left: Spacing.l, bottom: Spacing.s, right: Spacing.l))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
