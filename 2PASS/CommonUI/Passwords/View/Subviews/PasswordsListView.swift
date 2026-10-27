// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

final class PasswordsListView: UICollectionView {
    func configure(isAutoFillExtension: Bool) {
        register(ItemListSectionView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: ItemListSectionView.reuseIdentifier)
        
        keyboardDismissMode = .onDrag
    }

    /// The X range of the active vertical division crossing the list (iPhone Duo's hinge while the
    /// device is folded), in the list's coordinate space; `nil` on a flat or hingeless display.
    var verticalDivisionX: ClosedRange<CGFloat>? {
        guard #available(iOS 27.1, *) else { return nil }
        return reservedRegions(kind: .division)
            .filter { region in region.isActive && region.frame.height >= region.frame.width }
            .map { region in region.frame.minX...region.frame.maxX }
            .first { range in bounds.minX < range.lowerBound && range.upperBound < bounds.maxX }
    }
}
