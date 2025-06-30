// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import CommonUI

protocol EnterWordsFlowControllerParent: AnyObject {
    func enterWordsClose()
    func enterWordsToEnterMasterPassword(with entropy: Entropy, fileData: ExchangeVault)
    func enterWordsToEnterMasterPassword()
    func enterWordsToDecrypt(with masterKey: MasterKey, entropy: Entropy, fileData: ExchangeVault)
}

protocol EnterWordsFlowControlling: AnyObject {
    func close()
    func toAppSettings()
    func toEnterMasterPassword(entropy: Entropy, fileData: ExchangeVault)
    func toEnterMasterPassword()
    func toDecrypt(with masterKey: MasterKey, entropy: Entropy, fileData: ExchangeVault)
}

final class EnterWordsFlowController: FlowController {
    private weak var parent: EnterWordsFlowControllerParent?
    
    static func embedAsRoot(
        in viewController: UIViewController,
        parent: EnterWordsFlowControllerParent
    ) -> UIViewController {
        let view = EnterWordsViewController()
        let flowController = EnterWordsFlowController(viewController: view)
        flowController.parent = parent
        let interactor = ModuleInteractorFactory.shared.enterWordsModuleInteractor()
                
        let presenter = EnterWordsPresenter(
            flowController: flowController,
            interactor: interactor,
            fileData: nil
        )
        view.presenter = presenter
                
        viewController.placeChild(view)
        
        return view
    }
    
    static func push(
        on navigationController: UINavigationController,
        parent: EnterWordsFlowControllerParent,
        fileData: ExchangeVault
    ) {
        let view = EnterWordsViewController()
        let flowController = EnterWordsFlowController(viewController: view)
        flowController.parent = parent
        let interactor = ModuleInteractorFactory.shared.enterWordsModuleInteractor()

        let presenter = EnterWordsPresenter(
            flowController: flowController,
            interactor: interactor,
            fileData: fileData
        )
        view.presenter = presenter
        
        navigationController.pushViewController(view, animated: true)
    }
}

extension EnterWordsFlowController: EnterWordsFlowControlling {
    func close() {
        parent?.enterWordsClose()
    }
    
    func toAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }
    
    func toEnterMasterPassword(entropy: Entropy, fileData: ExchangeVault) {
        parent?.enterWordsToEnterMasterPassword(with: entropy, fileData: fileData)
    }
    
    func toDecrypt(with masterKey: MasterKey, entropy: Entropy, fileData: ExchangeVault) {
        parent?.enterWordsToDecrypt(with: masterKey, entropy: entropy, fileData: fileData)
    }
    
    func toEnterMasterPassword() {
        parent?.enterWordsToEnterMasterPassword()
    }
}

extension EnterWordsFlowController {
    var viewController: EnterWordsViewController { _viewController as! EnterWordsViewController }
}
