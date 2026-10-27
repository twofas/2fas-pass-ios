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
    static let minimumDividedSideWidth: CGFloat = 200
}

class ItemListLayout: UICollectionViewCompositionalLayout {

    static let minimumCellWidth: CGFloat = 310

    /// How a row's columns sit in the content width: across the whole width, or as two runs on either
    /// side of a division (iPhone Duo's hinge, in the layout's coordinate space) that no cell may cross.
    enum ColumnArrangement: Equatable {
        case continuous(columns: Int)
        case divided(leading: Side, trailing: Side)

        struct Side: Equatable {
            let width: CGFloat
            let columns: Int
        }

        var numberOfColumns: Int {
            switch self {
            case .continuous(let columns): columns
            case .divided(let leading, let trailing): leading.columns + trailing.columns
            }
        }
    }

    /// The arrangement for a content span and a division, both as X ranges in the same coordinate space.
    /// A division outside the span, or leaving a side too narrow for a cell, is ignored.
    static func columnArrangement(
        contentX: ClosedRange<CGFloat>,
        division: ClosedRange<CGFloat>?,
        contentSizeCategory: UIContentSizeCategory,
        layoutDirection: UITraitEnvironmentLayoutDirection
    ) -> ColumnArrangement {
        let width = contentX.upperBound - contentX.lowerBound
        guard let division else {
            return .continuous(columns: numberOfColumns(forAvailableWidth: width, contentSizeCategory: contentSizeCategory))
        }
        let leftWidth = division.lowerBound - contentX.lowerBound
        let rightWidth = contentX.upperBound - division.upperBound
        guard leftWidth >= Constants.minimumDividedSideWidth, rightWidth >= Constants.minimumDividedSideWidth else {
            return .continuous(columns: numberOfColumns(forAvailableWidth: width, contentSizeCategory: contentSizeCategory))
        }
        let left = ColumnArrangement.Side(
            width: leftWidth,
            columns: numberOfColumns(forAvailableWidth: leftWidth, contentSizeCategory: contentSizeCategory)
        )
        let right = ColumnArrangement.Side(
            width: rightWidth,
            columns: numberOfColumns(forAvailableWidth: rightWidth, contentSizeCategory: contentSizeCategory)
        )
        return layoutDirection == .rightToLeft ? .divided(leading: right, trailing: left) : .divided(leading: left, trailing: right)
    }

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

    /// `division` is the X range the cells must not cross, in the collection view's coordinate space.
    init(topInset: CGFloat, showSectionHeaders: Bool, division: ClosedRange<CGFloat>?) {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = Spacing.l

        super.init(sectionProvider: { sectionOffset, environment in
            let container = environment.container
            let contentMinX = container.contentInsets.leading
            let arrangement = ItemListLayout.columnArrangement(
                contentX: contentMinX...(contentMinX + container.effectiveContentSize.width),
                division: division,
                contentSizeCategory: environment.traitCollection.preferredContentSizeCategory,
                layoutDirection: environment.traitCollection.layoutDirection
            )

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(Constants.gridCellHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let group: NSCollectionLayoutGroup
            switch arrangement {
            case .continuous(let columns):
                group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
                        heightDimension: .absolute(Constants.gridCellHeight)
                    ),
                    repeatingSubitem: item,
                    count: columns
                )
            case .divided(let leading, let trailing):
                // One row is two runs of cells with the division's width left empty between them.
                let sideGroup = { (side: ColumnArrangement.Side) in
                    NSCollectionLayoutGroup.horizontal(
                        layoutSize: NSCollectionLayoutSize(
                            widthDimension: .absolute(side.width),
                            heightDimension: .absolute(Constants.gridCellHeight)
                        ),
                        repeatingSubitem: item,
                        count: side.columns
                    )
                }
                group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(Constants.gridCellHeight)
                    ),
                    subitems: [sideGroup(leading), sideGroup(trailing)]
                )
                group.interItemSpacing = .fixed(container.effectiveContentSize.width - leading.width - trailing.width)
            }

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
