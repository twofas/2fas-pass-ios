// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import SwiftUI

final class ItemEditorViewController: UIViewController {
    var presenter: ItemEditorPresenter!
    
    private let contentTypePicker = DropdownPicker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        addContentTypePicker()
            
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
            rootView: ItemEditorFormView(presenter: presenter, resignFirstResponder: { [weak self] in
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
    
    private func addContentTypePicker() {
        let contentTypeName = ItemContentTypeFormatStyle().format(presenter.contentType)
        
        if presenter.allowChangeContentType {
            contentTypePicker.selectedTitle = presenter.title
            contentTypePicker.menuItems = ItemContentType.allKnownTypes.map { contentType in
                let name = ItemContentTypeFormatStyle().format(contentType)
                let action = UIAction(title: name, image: contentType.icon, state: presenter.contentType == contentType ? .on : .off) { [weak self] _ in
                    self?.presenter.setContentType(contentType)
                    self?.contentTypePicker.selectedTitle = self?.presenter.title ?? ""
                }
                return action
            }
            navigationItem.titleView = contentTypePicker
        } else {
            navigationItem.title = presenter.title
        }
        
        navigationItem.largeTitleDisplayMode = .never
    }
}
