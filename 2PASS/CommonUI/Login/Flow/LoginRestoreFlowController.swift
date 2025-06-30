// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public protocol LoginRestoreFlowControllerParent: AnyObject {
    func loginRestoreSuccessful()
    func loginRestoreAppReset()
}

public final class LoginRestoreFlowController: FlowController {
    private static var defaultConfig: LoginModuleInteractorConfig {
        .init(allowBiometrics: false, loginType: .restore)
    }
    
    public static func embedAsRoot(
        in viewController: UIViewController,
        parent: LoginRestoreFlowControllerParent
    ) -> UIViewController {
        let view = LoginViewController()
        
        let interactor = ModuleInteractorFactory.shared.loginModuleInteractor(config: Self.defaultConfig)
                
        let presenter = LoginPresenter(
            loginSuccessful: {
                parent.loginRestoreSuccessful()
            },
            interactor: interactor,
            appReset: {
                parent.loginRestoreAppReset()
            }
        )
        view.presenter = presenter

        viewController.placeChild(view)
        
        return view
    }
}
