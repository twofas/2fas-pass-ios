// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

protocol ItemEditorFlowControllerParent: AnyObject {
    func closeItemEditor(with result: SaveItemResult)
    func itemEditorChangeProtectionLevel(
        current: ItemProtectionLevel,
        completion: @escaping (ItemProtectionLevel) -> Void
    )
    func itemEditorToCustomizeIcon(
        data: CustomizeIconData,
        completion: @escaping (PasswordIconType) -> Void
    )
    func itemEditorToSelectTags(
        selectedTags: [ItemTagData],
        onChange: @escaping ([ItemTagData]) -> Void
    )
}

protocol ItemEditorFlowControlling: AnyObject {
    func close(with result: SaveItemResult)
    func toChangeProtectionLevel(current: ItemProtectionLevel)
    func toCustomizeIcon(data: CustomizeIconData)
    func toSelectTags(selectedTags: [ItemTagData], onChange: @escaping ([ItemTagData]) -> Void)
}

final class ItemEditorFlowController: FlowController {
    private weak var parent: ItemEditorFlowControllerParent?
    
    static func setAsRoot(
        on navigationController: UINavigationController,
        parent: ItemEditorFlowControllerParent,
        editItemID: ItemID?,
        changeRequest: (any ItemDataChangeRequest)? = nil
    ) {
        let view = ItemEditorViewController()
        let flowController = ItemEditorFlowController(viewController: view)
        flowController.parent = parent
        let interactor = ModuleInteractorFactory.shared.itemEditorInteractor(
            editItemID: editItemID,
            changeRequest: changeRequest
        )

        let presenter = ItemEditorPresenter(
            flowController: flowController,
            interactor: interactor
        )
        view.presenter = presenter

        navigationController.setViewControllers([view], animated: false)
    }
}

extension ItemEditorFlowController: ItemEditorFlowControlling {

    func close(with result: SaveItemResult) {
        parent?.closeItemEditor(with: result)
    }

    func toChangeProtectionLevel(
        current: ItemProtectionLevel
    ) {
        parent?.itemEditorChangeProtectionLevel(current: current) { [weak viewController] newValue in
            viewController?.presenter.handleChangeProtectionLevel(newValue)
        }
    }

    func toCustomizeIcon(data: CustomizeIconData) {
        parent?.itemEditorToCustomizeIcon(data: data, completion: { [weak viewController] icon in
            viewController?.presenter.handleIconChange(icon)
        })
    }

    func toSelectTags(selectedTags: [ItemTagData], onChange: @escaping ([ItemTagData]) -> Void) {
        parent?.itemEditorToSelectTags(selectedTags: selectedTags, onChange: onChange)
    }
}

extension ItemEditorFlowController {
    var viewController: ItemEditorViewController { _viewController as! ItemEditorViewController }
}
