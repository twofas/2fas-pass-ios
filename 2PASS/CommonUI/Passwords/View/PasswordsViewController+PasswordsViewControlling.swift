// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

protocol PasswordsViewControlling: AnyObject {
    func reloadData(
        newSnapshot: NSDiffableDataSourceSnapshot<
            ItemSectionData,
            ItemCellData
        >
    )
    func showContentTypeFilterPicker(_ flag: Bool)
    func showList()
    func showEmptyScreen()
    func showSearchEmptyScreen()
    func filterDidChange()
    func clearSelectionForContentTypeChange()
    func exitEditingMode()
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
            reloadLayout()
        }
        
        dataSource?.apply(newSnapshot, animatingDifferences: true)
    }
    
    // MARK: - Empty screen or list
    func showList() {
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
    
    func showEmptyScreen() {
        VoiceOver.say(String(localized: .homeEmptyTitle))
        
        setEditing(false, animated: true)
        
        guard emptyList?.isHidden == true else { return }
        
        emptyList?.alpha = 0
        emptyList?.isHidden = false
        emptySearchList?.alpha = 1
        emptySearchList?.isHidden = true
        
        UIView.animate(withDuration: Animation.duration, animations: {
            self.emptyList?.alpha = 1
        })
    }
    
    func showSearchEmptyScreen() {
        VoiceOver.say(String(localized: .loginSearchNoResultsTitle))
        
        emptySearchList?.alpha = 0
        emptySearchList?.isHidden = false
        emptyList?.alpha = 0
        emptyList?.isHidden = true
        
        UIView.animate(
            withDuration: Animation.duration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            self.emptySearchList?.alpha = 1
        }
    }

    func clearSelectionForContentTypeChange() {
        clearSelection()
    }

    func exitEditingMode() {
        setEditing(false, animated: true)
    }
}
