// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol PasswordsNavigationFlowControllerParent: AnyObject {
    func toQuickSetup()
    func toPremiumPlanPrompt(itemsLimit: Int)

    @MainActor
    func toConfirmDelete() async -> Bool
}

public final class PasswordsNavigationFlowController: NavigationFlowController {
    private weak var parent: PasswordsNavigationFlowControllerParent?

    public static func showAsTab(
        in viewController: UITabBarController,
        parent: PasswordsNavigationFlowControllerParent
    ) {
        let flowController = PasswordsNavigationFlowController()
        flowController.parent = parent

        let navi = CommonNavigationControllerFlow(flowController: flowController)
        navi.tabBarItem = UITabBarItem(
            title: T.commonPasswords,
            image: UIImage(systemName: "lock.rectangle.stack"),
            selectedImage: UIImage(systemName: "lock.rectangle.stack")
        )
        
        flowController.navigationController = navi

        PasswordsFlowController.setAsRoot(
            on: navi,
            parent: flowController
        )
        
        viewController.addTab(navi)
    }
}

extension PasswordsNavigationFlowController: PasswordsFlowControllerParent {
    public func passwordsToViewPassword(passwordID: PasswordID) {
        ViewPasswordFlowController.push(
            on: navigationController,
            parent: self,
            passwordID: passwordID
        )
    }
    
    public func selectPassword(passwordID: PasswordID) {
        passwordsToViewPassword(passwordID: passwordID)
    }
    
    public func toQuickSetup() {
        parent?.toQuickSetup()
    }
    
    @MainActor
    public func toConfirmDelete() async -> Bool {
        await parent?.toConfirmDelete() ?? false
    }
    
    public func toPremiumPlanPrompt(itemsLimit: Int) {
        parent?.toPremiumPlanPrompt(itemsLimit: itemsLimit)
    }
    
    public func cancel() {
    }
}

extension PasswordsNavigationFlowController: ViewPasswordFlowControllerParent {
    func viewPasswordClose() {
        navigationController.popToRootViewController(animated: true)
    }
    
    func viewPasswordAutoFillTextToInsert(_ text: String) {}
}
