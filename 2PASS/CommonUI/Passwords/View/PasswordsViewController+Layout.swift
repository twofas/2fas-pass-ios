// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

private struct Constants {
    static let cellHeight: CGFloat = 82
}

extension PasswordsViewController {
    
    func makeLayout() -> UICollectionViewCompositionalLayout {
        if presenter.isAutoFillExtension {
            var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            configuration.headerMode = .supplementary
            configuration.backgroundColor = Asset.mainBackgroundColor.color
            configuration.showsSeparators = false
            return UICollectionViewCompositionalLayout.list(using: configuration)
        } else {
            let layout = UICollectionViewCompositionalLayout { [weak self] sectionOffset, enviroment in
                self?.getLayout(sectionOffset: sectionOffset, enviroment: enviroment)
            }
            
            // Add global header for tag banner when a tag is selected
            if presenter.selectedFilterTag != nil {
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(52)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: SelectedTagBannerView.elementKind,
                    alignment: .top
                )
                header.pinToVisibleBounds = true
                header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: Spacing.l, bottom: 0, trailing: Spacing.l)
                
                let configuration = UICollectionViewCompositionalLayoutConfiguration()
                configuration.boundarySupplementaryItems = [header]
                layout.configuration = configuration
            }
            
            return layout
        }
    }
    
    func getCell(
        for collectionView: UICollectionView,
        indexPath: IndexPath,
        item: PasswordCellData
    ) -> UICollectionViewCell? {
        let cell: PasswordsCellView? = collectionView.dequeueReusableCell(
            withReuseIdentifier: PasswordsCellView.reuseIdentifier,
            for: indexPath
        ) as? PasswordsCellView
        cell?.update(cellData: item)
        
        if let url = item.iconType.iconURL, let cachedData = presenter.cachedImage(from: url) {
            cell?.updateIcon(wirh: cachedData)
        }

        cell?.menuAction = { [weak self] action, passwordID, selectedURI in
            self?.presenter.onCellMenuAction(action, passwordID: passwordID, selectedURI: selectedURI)
        }
        return cell
    }
        
    func getLayout(sectionOffset: Int, enviroment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? {
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
            heightDimension: cellHeight()
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(itemsInRow)),
            heightDimension: cellHeight()
        )
        
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: itemsInRow
        )
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .zero
        
        return section
    }
    
    func cellHeight() -> NSCollectionLayoutDimension {
        .absolute(Constants.cellHeight)
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
