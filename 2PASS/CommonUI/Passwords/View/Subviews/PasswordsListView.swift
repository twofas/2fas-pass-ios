// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

final class PasswordsListView: UICollectionView {
    func configure(isAutoFillExtension: Bool) {
        backgroundColor = Asset.mainBackgroundColor.color
        
        if isAutoFillExtension {
            register(AutoFillPasswordsCellView.self, forCellWithReuseIdentifier: AutoFillPasswordsCellView.reuseIdentifier)
            register(AutoFillPasswordsSectionView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: AutoFillPasswordsSectionView.reuseIdentifier)
        } else {
            register(MainAppPasswordsCellView.self, forCellWithReuseIdentifier: MainAppPasswordsCellView.reuseIdentifier)
            register(SelectedTagBannerView.self, forSupplementaryViewOfKind: SelectedTagBannerView.elementKind, withReuseIdentifier: SelectedTagBannerView.reuseIdentifier)
        }
    }
}
