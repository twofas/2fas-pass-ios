// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

protocol ItemEditorNavigationFlowControllerParent: AnyObject {
    func closeItemEditor(with result: SaveItemResult)
}

final class ItemEditorNavigationFlowController: NavigationFlowController {
    private weak var parent: ItemEditorNavigationFlowControllerParent?

    static func present(
        on viewController: UIViewController,
        parent: ItemEditorNavigationFlowControllerParent,
        editItemID: ItemID?,
        changeRequest: (any ItemDataChangeRequest)? = nil,
        sourceView: UIView? = nil
    ) {
        let flowController = ItemEditorNavigationFlowController()
        flowController.parent = parent

        let navi = CommonNavigationControllerFlow(flowController: flowController)

        flowController.navigationController = navi

        ItemEditorFlowController.setAsRoot(
            on: navi,
            parent: flowController,
            editItemID: editItemID,
            changeRequest: changeRequest
        )

        if #available(iOS 26.0, *), let sourceView {
            navi.preferredTransition = .zoom(sourceViewProvider: { _ in sourceView })
        } else {
            navi.configureAsPhoneFullScreenModal()
        }
        viewController.present(navi, animated: true)
    }

    static func buildView(
        parent: ItemEditorNavigationFlowControllerParent,
        editItemID: ItemID?,
        changeRequest: (any ItemDataChangeRequest)?
    ) -> UIViewController {
        let flowController = ItemEditorNavigationFlowController()
        flowController.parent = parent

        let navi = CommonNavigationControllerFlow(flowController: flowController)

        flowController.navigationController = navi

        ItemEditorFlowController.setAsRoot(
            on: navi,
            parent: flowController,
            editItemID: editItemID,
            changeRequest: changeRequest,
        )

        return navi
    }
}

extension ItemEditorNavigationFlowController: ItemEditorFlowControllerParent {
    func closeItemEditor(with result: SaveItemResult) {
        parent?.closeItemEditor(with: result)
    }

    func itemEditorChangeProtectionLevel(
        current: ItemProtectionLevel,
        completion: @escaping (ItemProtectionLevel) -> Void
    ) {
        ChangeProtectionLevelFlowController.push(
            on: navigationController,
            parent: self,
            current: current,
            completion: completion
        )
    }

    func itemEditorToCustomizeIcon(
        data: CustomizeIconData,
        completion: @escaping (PasswordIconType) -> Void
    ) {
        CustomizeIconFlowController.push(
            on: navigationController,
            parent: self,
            data: data,
            completion: completion
        )
    }

    func itemEditorToSelectTags(
        selectedTags: [ItemTagData],
        onChange: @escaping ([ItemTagData]) -> Void
    ) {
        let selectTagsView = SelectTagsRouter.buildView(
            selectedTags: selectedTags,
            onChanged: onChange
        )

        let hostingController = UIHostingController(rootView: selectTagsView)
        hostingController.title = T.selectTagsTitle
        navigationController.pushViewController(hostingController, animated: true)
    }
}

extension ItemEditorNavigationFlowController: ChangeProtectionLevelFlowControllerParent {
    func closeProtectionLevel() {
        navigationController.popToRootViewController(animated: true)
    }
}

extension ItemEditorNavigationFlowController: CustomizeIconFlowControllerParent {
    func closeCustomizeIcon() {
        navigationController.popToRootViewController(animated: true)
    }
}
