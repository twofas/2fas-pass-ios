// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

final class BulkProtectionLevelViewController: UIViewController {
    var presenter: BulkProtectionLevelPresenter!

    private lazy var titleView: UIStackView = {
        let titleLabel = UILabel()
        titleLabel.text = String(localized: .homeMultiselectSecurityTierTitle)
        titleLabel.font = .headlineEmphasized
        titleLabel.textColor = .base1000
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = String(localized: .homeMultiselectSecurityTierSubtitle)
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .neutral900
        subtitleLabel.textAlignment = .center
        subtitleLabel.adjustsFontForContentSizeCategory = true
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Spacing.xxs
        return stackView
    }()
    
    private lazy var saveBarButton = UIBarButtonItem(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(onSaveTapped)
    )
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .base0
        
        navigationItem.titleView = titleView
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(onCancelTapped)
        )
        
        if #available(iOS 26.0, *) {
            saveBarButton.style = .prominent
        }
        
        navigationItem.rightBarButtonItem = saveBarButton
        updateSaveButtonState()
        
        let contentController = UIHostingController(rootView: BulkProtectionLevelSelectionView(presenter: presenter))
        self.presenter.onChange = { [weak self] in
            self?.updateSaveButtonState()
        }
        
        placeChild(contentController)
    }
}

private extension BulkProtectionLevelViewController {
    
    func updateSaveButtonState() {
        saveBarButton.isEnabled = presenter.hasPendingChanges
    }
    
    @objc
    func onCancelTapped() {
        presenter.handleCancel()
    }
    
    @objc
    func onSaveTapped() {
        presenter.handleSave(source: saveBarButton)
    }
}
