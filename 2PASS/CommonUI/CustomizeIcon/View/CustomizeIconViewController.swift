// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

final class CustomizeIconViewController: UIViewController {
    var presenter: CustomizeIconPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = T.customizeIcon
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: T.commonSave,
            style: .plain,
            target: self,
            action: #selector(saveAction)
        )
        
        presenter.enableSave = { [weak self] enabled in
            self?.navigationItem.rightBarButtonItem?.isEnabled = enabled
        }
        
        let vc = UIHostingController(rootView: CustomizeIconView(presenter: presenter))
        placeChild(vc)
    }
    
    @objc
    private func saveAction() {
        presenter.onSave()
    }
}
