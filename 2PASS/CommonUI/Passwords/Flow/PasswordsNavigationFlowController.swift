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
    
    @MainActor
    func toConfirmMultiselectDelete(selectedCount: Int, source: UIBarButtonItem?) async -> Bool
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
            title: String(localized: .commonPasswords),
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
    public func passwordsToItemDetail(itemID: ItemID) {
        ItemDetailFlowController.push(
            on: navigationController,
            parent: self,
            itemID: itemID
        )
    }

    public func selectItem(id: ItemID, contentType: ItemContentType) {
        passwordsToItemDetail(itemID: id)
    }
    
    public func toQuickSetup() {
        parent?.toQuickSetup()
    }
    
    @MainActor
    public func toConfirmDelete() async -> Bool {
        await parent?.toConfirmDelete() ?? false
    }

    @MainActor
    public func toConfirmMultiselectDelete(selectedCount: Int, source: UIBarButtonItem?) async -> Bool {
        await parent?.toConfirmMultiselectDelete(selectedCount: selectedCount, source: source) ?? false
    }
    
    public func toPremiumPlanPrompt(itemsLimit: Int) {
        parent?.toPremiumPlanPrompt(itemsLimit: itemsLimit)
    }
    
    public func cancel() {
    }
}

extension PasswordsNavigationFlowController: ItemDetailFlowControllerParent {
    func itemDetailClose() {
        navigationController.popToRootViewController(animated: true)
    }

    func itemDetailAutoFillTextToInsert(_ text: String) {}
}
