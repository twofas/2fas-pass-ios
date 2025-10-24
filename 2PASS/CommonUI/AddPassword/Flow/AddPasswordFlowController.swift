// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

protocol AddPasswordFlowControllerParent: AnyObject {
    func closeAddPassword(with result: SavePasswordResult)
    func addPasswordChangeProtectionLevel(
        current: ItemProtectionLevel,
        completion: @escaping (ItemProtectionLevel) -> Void
    )
    func addPasswordToCustomizeIcon(
        data: CustomizeIconData,
        completion: @escaping (PasswordIconType) -> Void
    )
    func addPasswordToSelectTags(
        selectedTags: [ItemTagData],
        onChange: @escaping ([ItemTagData]) -> Void
    )
}

protocol AddPasswordFlowControlling: AnyObject {
    func close(with result: SavePasswordResult)
    func toChangeProtectionLevel(current: ItemProtectionLevel)
    func toCustomizeIcon(data: CustomizeIconData)
    func toSelectTags(selectedTags: [ItemTagData], onChange: @escaping ([ItemTagData]) -> Void)
}

final class AddPasswordFlowController: FlowController {
    private weak var parent: AddPasswordFlowControllerParent?
    
    static func setAsRoot(
        on navigationController: UINavigationController,
        parent: AddPasswordFlowControllerParent,
        editItemID: ItemID?,
        changeRequest: PasswordDataChangeRequest? = nil
    ) {
        let view = AddPasswordViewController()
        let flowController = AddPasswordFlowController(viewController: view)
        flowController.parent = parent
        let interactor = ModuleInteractorFactory.shared.addPasswordInteractor(
            editItemID: editItemID,
            changeRequest: changeRequest
        )
        
        let presenter = AddPasswordPresenter(
            flowController: flowController,
            interactor: interactor
        )
        view.presenter = presenter

        navigationController.setViewControllers([view], animated: false)
    }
}

extension AddPasswordFlowController: AddPasswordFlowControlling {
    
    func close(with result: SavePasswordResult) {
        parent?.closeAddPassword(with: result)
    }
    
    func toChangeProtectionLevel(
        current: ItemProtectionLevel
    ) {
        parent?.addPasswordChangeProtectionLevel(current: current) { [weak viewController] newValue in
            viewController?.presenter.handleChangeProtectionLevel(newValue)
        }
    }
    
    func toCustomizeIcon(data: CustomizeIconData) {
        parent?.addPasswordToCustomizeIcon(data: data, completion: { [weak viewController] icon in
            viewController?.presenter.handleIconChange(icon)
        })
    }
    
    func toSelectTags(selectedTags: [ItemTagData], onChange: @escaping ([ItemTagData]) -> Void) {
        parent?.addPasswordToSelectTags(selectedTags: selectedTags, onChange: onChange)
    }
}

extension AddPasswordFlowController {
    var viewController: AddPasswordViewController { _viewController as! AddPasswordViewController }
}
