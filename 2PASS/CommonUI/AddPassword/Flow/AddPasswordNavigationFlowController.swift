// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol AddPasswordNavigationFlowControllerParent: AnyObject {
    func closeAddPassword(with result: SavePasswordResult)
}

final class AddPasswordNavigationFlowController: NavigationFlowController {
    private weak var parent: AddPasswordNavigationFlowControllerParent?

    static func present(
        on viewController: UIViewController,
        parent: AddPasswordNavigationFlowControllerParent,
        editPasswordID: PasswordID?,
        changeRequest: PasswordDataChangeRequest? = nil
    ) {
        let flowController = AddPasswordNavigationFlowController()
        flowController.parent = parent

        let navi = CommonNavigationControllerFlow(flowController: flowController)
        
        flowController.navigationController = navi

        AddPasswordFlowController.setAsRoot(
            on: navi,
            parent: flowController,
            editPasswordID: editPasswordID,
            changeRequest: changeRequest
        )
        
        navi.configureAsPhoneFullScreenModal()
        viewController.present(navi, animated: true)
    }
    
    static func buildView(
        parent: AddPasswordNavigationFlowControllerParent,
        editPasswordID: PasswordID?,
        changeRequest: PasswordDataChangeRequest?
    ) -> UIViewController {
        let flowController = AddPasswordNavigationFlowController()
        flowController.parent = parent

        let navi = CommonNavigationControllerFlow(flowController: flowController)
        
        flowController.navigationController = navi

        AddPasswordFlowController.setAsRoot(
            on: navi,
            parent: flowController,
            editPasswordID: editPasswordID,
            changeRequest: changeRequest,
        )
        
        return navi
    }
}

extension AddPasswordNavigationFlowController: AddPasswordFlowControllerParent {
    func closeAddPassword(with result: SavePasswordResult) {
        parent?.closeAddPassword(with: result)
    }
    
    func addPasswordChangeProtectionLevel(
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
    
    func addPasswordToCustomizeIcon(
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
}

extension AddPasswordNavigationFlowController: ChangeProtectionLevelFlowControllerParent {
    func closeProtectionLevel() {
        navigationController.popToRootViewController(animated: true)
    }
}

extension AddPasswordNavigationFlowController: CustomizeIconFlowControllerParent {
    func closeCustomizeIcon() {
        navigationController.popToRootViewController(animated: true)
    }
}
