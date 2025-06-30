// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol CustomizeIconFlowControllerParent: AnyObject {
    func closeCustomizeIcon()
}

protocol CustomizeIconFlowControlling: AnyObject {
    func toSave(value: PasswordIconType)
    func close()
}

final class CustomizeIconFlowController: FlowController {
    private weak var parent: CustomizeIconFlowControllerParent?
    private var completion: ((PasswordIconType) -> Void)?
    
    static func push(
        on navigationController: UINavigationController,
        parent: CustomizeIconFlowControllerParent,
        data: CustomizeIconData,
        completion: @escaping (PasswordIconType) -> Void
    ) {
        let view = CustomizeIconViewController()
        let flowController = CustomizeIconFlowController(viewController: view)
        flowController.parent = parent
        flowController.completion = completion
        
        let interactor = ModuleInteractorFactory.shared.customizeIconInteractor()
        
        let presenter = CustomizeIconPresenter(
            data: data,
            flowController: flowController,
            interactor: interactor
        )
        view.presenter = presenter

        navigationController.pushViewController(view, animated: true)
    }
}

extension CustomizeIconFlowController: CustomizeIconFlowControlling {
    func toSave(value: PasswordIconType) {
        completion?(value)
        close()
    }
    
    func close() {
        parent?.closeCustomizeIcon()
    }
}

extension CustomizeIconFlowController {
    var viewController: CustomizeIconViewController { _viewController as! CustomizeIconViewController }
}

