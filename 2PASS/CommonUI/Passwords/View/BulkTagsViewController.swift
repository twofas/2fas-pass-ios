// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

final class BulkTagsViewController: UIViewController {
    var presenter: BulkTagsPresenter!

    private lazy var titleView: UIStackView = {
        let titleLabel = UILabel()
        titleLabel.text = String(localized: .homeMultiselectTagsTitle)
        titleLabel.font = .headlineEmphasized
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        let subtitleLabel = UILabel()
        subtitleLabel.text = String(localized: .homeMultiselectTagsSubtitle)
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.adjustsFontForContentSizeCategory = true

        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 0
        return stackView
    }()

    private lazy var doneBarButton = UIBarButtonItem(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(onDoneTapped)
    )

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .base0

        navigationItem.titleView = titleView
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(onCancel)
        )

        if #available(iOS 26.0, *) {
            doneBarButton.style = .prominent
        }

        navigationItem.rightBarButtonItem = doneBarButton
        updateDoneButtonState()

        let contentController = UIHostingController(rootView: BulkTagsRouter.buildView(presenter: presenter))
        presenter.onChange = { [weak self] in
            self?.updateDoneButtonState()
        }

        placeChild(contentController)
    }
}

private extension BulkTagsViewController {

    func updateDoneButtonState() {
        doneBarButton.isEnabled = presenter.hasPendingChanges
    }

    @objc
    func onCancel() {
        presenter.handleCancel()
    }

    @objc
    func onDoneTapped() {
        presenter.handleSave()
    }
}
