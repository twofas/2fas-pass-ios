// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

private struct Constants {
    static let gridCellHeight: CGFloat = 68
    static let tagBannerHeight: CGFloat = 52
    static let headerHeight: CGFloat = 28
}

extension PasswordsViewController {

    func makeLayout() -> UICollectionViewCompositionalLayout {
        let config = UICollectionViewCompositionalLayoutConfiguration()

        if presenter.selectedFilterTag != nil {
            let bannerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(Constants.tagBannerHeight)
            )

            let banner = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: bannerSize,
                elementKind: SelectedTagBannerView.elementKind,
                alignment: .top
            )
            banner.pinToVisibleBounds = true
            banner.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: Spacing.l, bottom: 0, trailing: Spacing.l)
            banner.zIndex = 2

            config.boundarySupplementaryItems = [banner]
        }

        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] sectionOffset, enviroment in
            self?.getLayout(sectionOffset: sectionOffset, enviroment: enviroment)
        }, configuration: config)

        return layout
    }

    func getLayout(sectionOffset: Int, enviroment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
        let section: NSCollectionLayoutSection
        let minimumCellWidth: CGFloat = 310
        let itemsInRow: Int = {
            let availableWidth = enviroment.container.effectiveContentSize.width
            var columns = Int(availableWidth / minimumCellWidth)
            let layoutMultiplier = enviroment.traitCollection.preferredContentSizeCategory.layoutMultiplier
            if columns > 1 && layoutMultiplier != 1.0 {
                let newSize = minimumCellWidth * layoutMultiplier
                columns = Int(availableWidth / newSize)
            }
            if columns < 1 {
                columns = 1
            }
            return columns
        }()
                
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: gridCellHeight()
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(itemsInRow)),
            heightDimension: gridCellHeight()
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: itemsInRow
        )
        
        section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .zero
        section.interGroupSpacing = Spacing.xs
        
        if presenter.hasSuggestedItems {
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(Constants.headerHeight)
            )

            let topPadding: CGFloat = sectionOffset == 0 ? (presenter.selectedFilterTag != nil ? 48 : 36) : 0

            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top,
                absoluteOffset: .init(x: 0, y: topPadding)
            )
            header.pinToVisibleBounds = true
            section.contentInsets.top = topPadding
            section.boundarySupplementaryItems = [header]
        }

        return section
    }
    
    func gridCellHeight() -> NSCollectionLayoutDimension {
         .absolute(Constants.gridCellHeight)
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
