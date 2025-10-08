// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

final class AddPasswordViewController: UIViewController {
    var presenter: AddPasswordPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = presenter.isEdit ? T.loginEditTitle : T.loginAddTitle
        navigationItem.largeTitleDisplayMode = .never
        
        if #available(iOS 26.0, *) {
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(actionCancel))
            navigationItem.leftBarButtonItem = cancelButton
            
            let saveButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveAction))
            saveButton.style = .prominent
            navigationItem.rightBarButtonItem = saveButton
        } else {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: T.commonCancel,
                style: .plain,
                target: self,
                action: #selector(actionCancel)
            )
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: T.commonSave,
                style: .plain,
                target: self,
                action: #selector(saveAction)
            )
        }
        navigationItem.backButtonDisplayMode = .minimal
        
        presenter.saveEnabled = { [weak self] enabled in
            self?.navigationItem.rightBarButtonItem?.isEnabled = enabled
        }
        
        let vc = UIHostingController(
            rootView: AddPasswordView(presenter: presenter, resignFirstResponder: { [weak self] in
                self?.view.endEditing(true)
        }))
        placeChild(vc)
    }
    
    @objc
    private func actionCancel() {
        presenter.onClose()
    }
    
    @objc
    private func saveAction() {
        presenter.onSave()
    }
}
