// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import SwiftUI

public struct AutoFillEnvironment {
    let serviceIdentifiers: [String]
    let isTextToInsert: Bool
}

public protocol AutofillPasswordsNavigationFlowControllerParent: AnyObject {
    func selectPassword(itemID: ItemID)
    
    @available(iOS 18.0, *)
    func textToInsert(_ text: String)
    
    func cancel()
}

public final class AutofillPasswordsNavigationFlowController: NavigationFlowController {
    private weak var parent: AutofillPasswordsNavigationFlowControllerParent?
    private var autoFillEnvironment: AutoFillEnvironment
    
    public static func setAsRoot(
        parent: AutofillPasswordsNavigationFlowControllerParent,
        serviceIdentifiers: [String],
        isTextToInsert: Bool
    ) -> UINavigationController {
        let autoFillEnvironment = AutoFillEnvironment(serviceIdentifiers: serviceIdentifiers, isTextToInsert: isTextToInsert)
        let flowController = AutofillPasswordsNavigationFlowController(autoFillEnvironment: autoFillEnvironment)
        flowController.parent = parent

        let navigationController = CommonNavigationControllerFlow(flowController: flowController)
        flowController.navigationController = navigationController
        
        PasswordsFlowController.setAsRoot(
            on: navigationController,
            parent: flowController,
            autoFillEnvironment: autoFillEnvironment
        )
        
        return navigationController
    }
    
    init(autoFillEnvironment: AutoFillEnvironment) {
        self.autoFillEnvironment = autoFillEnvironment
    }
}

extension AutofillPasswordsNavigationFlowController: PasswordsFlowControllerParent {
    public var isDetailColumnVisible: Bool { false }

    public var openDetailItemID: ItemID? { nil }

    public func clearDetailSelection() {}

    public func showMultiselectDetail(selectedCount: Int) {}

    public func showEmptyVaultDetail() {}

    public func restoreItemsSearchPhrase(_ phrase: String?) {}

    public func passwordsToItemDetail(itemID: ItemID) {
        ItemDetailFlowController.push(
            on: navigationController,
            parent: self,
            itemID: itemID,
            autoFillEnvironment: autoFillEnvironment
        )
    }

    public func selectItem(id: ItemID, contentType: ItemContentType) {
        if autoFillEnvironment.isTextToInsert || contentType != .login {
            passwordsToItemDetail(itemID: id)
        } else {
            parent?.selectPassword(itemID: id)
        }
    }
    
    public func cancel() {
        parent?.cancel()
    }
    
    public func toQuickSetup() {
    }
    
    public func toPremiumPlanPrompt(itemsLimit: Int) {
        let controller = UIHostingController(
            rootView: PremiumPromptRouter.buildView(
                title: Text(.paywallNoticeItemsLimitReachedTitle),
                description: Text(.paywallNoticeItemsLimitReachedMsg(Int32(itemsLimit)))
            )
        )
        
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.custom(resolver: { context in
                if context.containerTraitCollection.userInterfaceIdiom == .phone {
                    return PremiumPromptViewConstants.sheetHeight
                } else {
                    return context.maximumDetentValue
                }
            })]
        }
        
        navigationController?.present(controller, animated: true)
    }
}

extension AutofillPasswordsNavigationFlowController: ItemDetailFlowControllerParent {
    func itemDetailToEdit(_ itemID: ItemID) {
        // AutoFill never reparents its subtree, so its own nav is a stable in-window host and parent.
        ItemEditorNavigationFlowController.present(
            on: navigationController,
            parent: self,
            editItemID: itemID
        )
    }

    func itemDetailModalPresenter() -> UIViewController {
        // AutoFill never reparents its subtree, so its own nav is a stable in-window host.
        navigationController
    }

    func itemDetailClose() {
        navigationController.popToRootViewController(animated: true)
    }

    @available(iOS 18.0, *)
    func itemDetailAutoFillTextToInsert(_ text: String) {
        parent?.textToInsert(text)
    }
}

extension AutofillPasswordsNavigationFlowController: ItemEditorNavigationFlowControllerParent {
    func closeItemEditor(with result: SaveItemResult) {
        navigationController.dismiss(animated: true)
    }
}
