// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import CommonUI
import SwiftUI

protocol RestoreVaultFlowControllerParent: AnyObject {
    func restoreVaultClose()
}

final class RestoreVaultFlowController: FlowController {
    private weak var parent: RestoreVaultFlowControllerParent?
    
    static func embedAsRoot(
        in viewController: UIViewController,
        parent: RestoreVaultFlowControllerParent
    ) -> UIViewController {
        let view = UIHostingController(
            rootView: RestoreVaultRouter.buildView(onClose: {
                parent.restoreVaultClose()
            })
        )
        
        let flowController = RestoreVaultFlowController(viewController: view)
        flowController.parent = parent
                
        viewController.placeChild(view)
        
        return view
    }
}
