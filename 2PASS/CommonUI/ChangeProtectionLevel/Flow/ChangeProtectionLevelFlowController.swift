// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol ChangeProtectionLevelFlowControllerParent: AnyObject {
    func closeProtectionLevel()
}

protocol ChangeProtectionLevelFlowControlling: AnyObject {
    func toSelectedProtectionLevel(value: PasswordProtectionLevel)
    func close()
}

final class ChangeProtectionLevelFlowController: FlowController {
    private weak var parent: ChangeProtectionLevelFlowControllerParent?
    private var completion: ((PasswordProtectionLevel) -> Void)?
    
    static func push(
        on navigationController: UINavigationController,
        parent: ChangeProtectionLevelFlowControllerParent,
        current: PasswordProtectionLevel,
        completion: @escaping (PasswordProtectionLevel) -> Void
    ) {
        let view = ChangeProtectionLevelViewController()
        let flowController = ChangeProtectionLevelFlowController(viewController: view)
        flowController.parent = parent
        flowController.completion = completion
                
        let presenter = ChangeProtectionLevelPresenter(
            flowController: flowController,
            currentProtectionLevel: current
        )
        view.presenter = presenter

        navigationController.pushViewController(view, animated: true)
    }
}

extension ChangeProtectionLevelFlowController: ChangeProtectionLevelFlowControlling {
    func toSelectedProtectionLevel(value: PasswordProtectionLevel) {
        completion?(value)
    }
    
    func close() {
        parent?.closeProtectionLevel()
    }
}

extension ChangeProtectionLevelFlowController {
    var viewController: ChangeProtectionLevelViewController { _viewController as! ChangeProtectionLevelViewController }
}

