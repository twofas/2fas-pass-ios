// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

extension PasswordsViewController: UICollectionViewDelegate {
    
    // MARK: - Scroll View Delegate
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let contentTypePicker else { return }

        if UIDevice.isiPad {
            contentTypePicker.alpha = presenter.showContentTypePicker ? 1 : 0
        } else {
            let offset = scrollView.adjustedContentInset.top + scrollView.contentOffset.y
            setContentTypePickerOffset(min(0, -offset))
            contentTypePicker.alpha = presenter.showContentTypePicker ? (1 - (offset / contentTypePicker.frame.height)) : 0
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard presenter.showContentTypePicker, UIDevice.isiPad == false else { return }
        guard let contentTypePicker else { return }
        
        let topInset = -scrollView.adjustedContentInset.top
        
        switch targetContentOffset.pointee.y {
        case (topInset..<topInset + contentTypePicker.frame.height/2):
            targetContentOffset.pointee.y = topInset
        case (topInset + contentTypePicker.frame.height/2..<topInset + contentTypePicker.frame.height):
            targetContentOffset.pointee.y = topInset + contentTypePicker.frame.height
        default:
            break
        }
    }
    
    // MARK: - Select
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.isEditing {
            updateSelectionUI()
        } else {
            collectionView.deselectItem(at: indexPath, animated: false)
            presenter.onDidSelectAt(indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if collectionView.isEditing {
            updateSelectionUI()
        }
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
        guard collectionView.isEditing == false else { return nil }
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
