// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

private struct Constants {
    static let gridCellHeight: CGFloat = 68
    static let firstSectionHeaderOffset: CGFloat = 44
    static let sectionHeaderHeight: CGFloat = 28
}

class ItemListLayout: UICollectionViewCompositionalLayout {

    static let minimumCellWidth: CGFloat = 310

    /// Number of grid columns for the given available width and content size category. Shared with
    /// the view controller so it can tell when the list is rendering as a multi-column grid without
    /// duplicating the sizing math.
    static func numberOfColumns(forAvailableWidth availableWidth: CGFloat, contentSizeCategory: UIContentSizeCategory) -> Int {
        var columns = Int(availableWidth / minimumCellWidth)
        let layoutMultiplier = contentSizeCategory.layoutMultiplier
        if columns > 1 && layoutMultiplier != 1.0 {
            let newSize = minimumCellWidth * layoutMultiplier
            columns = Int(availableWidth / newSize)
        }
        if columns < 1 {
            columns = 1
        }
        return columns
    }

    init(topInset: CGFloat, showSectionHeaders: Bool) {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = Spacing.l

        super.init(sectionProvider: { sectionOffset, environment in
            let itemsInRow = ItemListLayout.numberOfColumns(
                forAvailableWidth: environment.container.effectiveContentSize.width,
                contentSizeCategory: environment.traitCollection.preferredContentSizeCategory
            )

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(Constants.gridCellHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / CGFloat(itemsInRow)),
                heightDimension: .absolute(Constants.gridCellHeight)
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: itemsInRow
            )

            let section = NSCollectionLayoutSection(group: group)
            if sectionOffset == 0 {
                section.contentInsets.top = topInset
            }

            section.interGroupSpacing = Spacing.xs

            if showSectionHeaders {
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(Constants.sectionHeaderHeight)
                )

                let offset: CGFloat = sectionOffset == 0 ? Constants.firstSectionHeaderOffset : 0
                
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top,
                    absoluteOffset: .init(x: 0, y: offset)
                )

                header.pinToVisibleBounds = true
                section.contentInsets.top += offset

                section.boundarySupplementaryItems = [header]
            }
            
            return section
        }, configuration: config)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension UIContentSizeCategory {
    var layoutMultiplier: CGFloat {
        switch self {
        case UIContentSizeCategory.accessibilityExtraExtraExtraLarge: return 23.0 / 16.0
        case UIContentSizeCategory.accessibilityExtraExtraLarge: return 22.0 / 16.0
        case UIContentSizeCategory.accessibilityExtraLarge: return 21.0 / 16.0
        case UIContentSizeCategory.accessibilityLarge: return 20.0 / 16.0
        case UIContentSizeCategory.accessibilityMedium: return 19.0 / 16.0
        case UIContentSizeCategory.extraExtraExtraLarge: return 19.0 / 16.0
        case UIContentSizeCategory.extraExtraLarge: return 18.0 / 16.0
        case UIContentSizeCategory.extraLarge: return 17.0 / 16.0
        case UIContentSizeCategory.large: return 1.0
        case UIContentSizeCategory.medium: return 15.0 / 16.0
        case UIContentSizeCategory.small: return 14.0 / 16.0
        case UIContentSizeCategory.extraSmall: return 13.0 / 16.0
        default: return 1.0
        }
    }
}
