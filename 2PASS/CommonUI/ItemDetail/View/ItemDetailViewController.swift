// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

final class ItemDetailViewController: UIViewController {
    var presenter: ItemDetailPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: String(localized: .loginEdit),
            style: .plain,
            target: self,
            action: #selector(editAction)
        )
        navigationItem.backButtonDisplayMode = .minimal
        
        let vc = UIHostingController(
            rootView: ItemDetailView(presenter: presenter)
        )
        placeChild(vc)
    }
    
    @objc
    private func editAction() {
        presenter.onEdit()
    }
}
