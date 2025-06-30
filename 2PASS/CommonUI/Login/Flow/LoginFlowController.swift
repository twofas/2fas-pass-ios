// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public protocol LoginFlowControllerParent: AnyObject {
    func loginSuccessful()
}

public final class LoginFlowController: FlowController {
    
    private static var defaultConfig: LoginModuleInteractorConfig {
        .init(allowBiometrics: true, loginType: .login)
    }
    
    public static func setAsCover(
        in window: UIWindow,
        coldRun: Bool,
        parent: LoginFlowControllerParent
    ) -> LoginViewController {
        let view = LoginViewController()
        let interactor = ModuleInteractorFactory.shared.loginModuleInteractor(config: Self.defaultConfig)
        let presenter = LoginPresenter(
            coldRun: coldRun,
            loginSuccessful: {
                parent.loginSuccessful()
            },
            interactor: interactor
        )
        view.presenter = presenter
        
        window.rootViewController = view
        
        return view
    }
}
