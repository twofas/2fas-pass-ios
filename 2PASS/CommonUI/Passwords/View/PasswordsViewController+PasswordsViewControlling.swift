// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

protocol PasswordsViewControlling: AnyObject {
    func reloadData(
        newSnapshot: NSDiffableDataSourceSnapshot<
            PasswordSectionData,
            PasswordCellData
        >
    )
    func showList()
    func showEmptyScreen()
    func showSearchEmptyScreen()
}

extension PasswordsViewController: PasswordsViewControlling {
    func reloadData(
        newSnapshot: NSDiffableDataSourceSnapshot<
            PasswordSectionData,
            PasswordCellData
        >
    ) {
        dataSource?.apply(newSnapshot, animatingDifferences: true)
    }
    
    // MARK: - Empty screen or list
    func showList() {
        passwordsList?.isScrollEnabled = true
        container.isUserInteractionEnabled = false
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
        passwordsList?.isScrollEnabled = false
        VoiceOver.say(T.homeEmptyMsg)
        guard emptyList?.isHidden == true else { return }
        emptyList?.alpha = 0
        emptyList?.isHidden = false
        UIView.animate(withDuration: Animation.duration, animations: {
            self.emptyList?.alpha = 1
            self.container.isUserInteractionEnabled = true
        })
    }
    
    func showSearchEmptyScreen() {
        passwordsList?.isScrollEnabled = false
        VoiceOver.say(T.loginSearchNoResultsTitle)
        emptySearchList?.alpha = 0
        emptySearchList?.isHidden = false
        UIView.animate(
            withDuration: Animation.duration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut]
        ) {
            self.emptySearchList?.alpha = 1
            self.container.isUserInteractionEnabled = true
        }
    }
}
