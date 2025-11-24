// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

private struct Constants {
    static let contentTypePickerHideOffset: CGFloat = 50
}

extension PasswordsViewController: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        
        if let contentTypePicker = passwordsList?.visibleSupplementaryViews(ofKind: ItemContentTypeFilterPickerView.elementKind).first {
            contentTypePicker.alpha = 1 - (offset / Constants.contentTypePickerHideOffset)
            contentTypePicker.transform = .init(translationX: 0, y: offset < 0 ? offset : 0)
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let topInset = -scrollView.adjustedContentInset.top
        
        switch targetContentOffset.pointee.y {
        case (topInset..<topInset + Constants.contentTypePickerHideOffset/2):
            targetContentOffset.pointee.y = topInset
        case (topInset + Constants.contentTypePickerHideOffset/2..<topInset + Constants.contentTypePickerHideOffset):
            targetContentOffset.pointee.y = topInset + Constants.contentTypePickerHideOffset
        default:
            break
        }
    }
    
    // MARK: - Select
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        presenter.onDidSelectAt(indexPath)
    }
    
    // MARK: - Cell Display
    
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let passwordData = dataSource?.itemIdentifier(for: indexPath) else { return }

        if let url = passwordData.iconType.iconURL {
            presenter.fetchImage(from: url, for: passwordData)
        }
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let passwordData = dataSource?.itemIdentifier(for: indexPath) else { return }
        presenter.cancelFetches(for: passwordData)
    }
    
    // MARK: - Context Menu
    
    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemsAt indexPaths: [IndexPath],
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first,
              let item = dataSource?.itemIdentifier(for: indexPath),
              let cell = collectionView.cellForItem(at: indexPath) as? ItemCellView else {
            return nil
        }

        return UIContextMenuConfiguration(
            identifier: indexPath as NSIndexPath,
            previewProvider: { return nil }
        ) { _ in
            return cell.menu(for: item)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplayContextMenu configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        guard let indexPath = configuration.identifier as? NSIndexPath,
              let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? ItemCellView else {
            return
        }

        animator?.addAnimations {
            cell.setMenuButtonHidden(true)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willEndContextMenuInteraction configuration: UIContextMenuConfiguration,
        animator: (any UIContextMenuInteractionAnimating)?
    ) {
        guard let indexPath = configuration.identifier as? NSIndexPath,
              let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? ItemCellView else {
            return
        }

        animator?.addAnimations {
            cell.setMenuButtonHidden(false)
        }
    }
}

