// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol PasswordsViewControlling: AnyObject {
    func reloadData(
        newSnapshot: NSDiffableDataSourceSnapshot<
            ItemSectionData,
            ItemCellData
        >
    )
    func showContentTypeFilterPicker(_ flag: Bool)
    func restoreSearchPhrase(_ phrase: String?)
    func showList(animated: Bool)
    func showEmptyScreen(animated: Bool)
    func showSearchEmptyScreen(animated: Bool)
    func filterDidChange()
    func exitEditingMode()
    func highlightRow(for itemID: ItemID)
    func clearRowHighlight()
}

extension PasswordsViewController: PasswordsViewControlling {
    
    func reloadData(
        newSnapshot: NSDiffableDataSourceSnapshot<
            ItemSectionData,
            ItemCellData
        >
    ) {
        updateNavigationBarButtons()
        
        if let passwordsList, dataSource?.numberOfSections(in: passwordsList) != newSnapshot.sectionIdentifiers.count {
            reloadLayout(animated: true)
        }

        dataSource?.apply(newSnapshot, animatingDifferences: true) { [weak self] in
            // Reconcile multiselect once the snapshot's index paths are valid — covers restoring a
            // selection made in the other layout, independent of which appearance callbacks fired.
            self?.reconcileSelection()
        }
    }
    
    // MARK: - Empty screen or list
    func showList(animated: Bool) {
        guard animated else {
            emptyList?.alpha = 0
            emptyList?.isHidden = true
            emptySearchList?.alpha = 0
            emptySearchList?.isHidden = true
            return
        }
        UIView.animate(
            withDuration: Animation.duration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: {
                self.emptyList?.alpha = 0
                self.emptySearchList?.alpha = 0
            },
            completion: { _ in
                self.emptyList?.isHidden = true
                self.emptySearchList?.isHidden = true
            }
        )
    }

    func showEmptyScreen(animated: Bool) {
        VoiceOver.say(String(localized: .homeEmptyTitle))

        setEditing(false, animated: animated)

        guard emptyList?.isHidden == true else { return }

        emptyList?.isHidden = false
        emptySearchList?.alpha = 1
        emptySearchList?.isHidden = true

        guard animated else {
            emptyList?.alpha = 1
            return
        }
        emptyList?.alpha = 0
        UIView.animate(withDuration: Animation.duration, animations: {
            self.emptyList?.alpha = 1
        })
    }

    func showSearchEmptyScreen(animated: Bool) {
        VoiceOver.say(String(localized: .loginSearchNoResultsTitle))

        emptySearchList?.isHidden = false
        emptyList?.alpha = 0
        emptyList?.isHidden = true

        guard animated else {
            emptySearchList?.alpha = 1
            return
        }
        emptySearchList?.alpha = 0
        UIView.animate(
            withDuration: Animation.duration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            self.emptySearchList?.alpha = 1
        }
    }

    func exitEditingMode() {
        setEditing(false, animated: true)
    }

    func highlightRow(for itemID: ItemID) {
        guard isEditing == false, let dataSource, let passwordsList else { return }

        guard let cellData = dataSource.snapshot().itemIdentifiers.first(where: { $0.itemID == itemID }),
              let indexPath = dataSource.indexPath(for: cellData) else {
            return
        }

        passwordsList.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }

    /// Removes the persistent detail-row highlight. Multiselect checkmarks are untouched — while
    /// editing, row selection belongs to `reconcileSelection`.
    func clearRowHighlight() {
        guard isEditing == false else { return }
        clearSelection()
    }
}
