// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import SwiftUI

public protocol PasswordsFlowControllerParent: AnyObject {
    func passwordsToItemDetail(itemID: ItemID)
    func selectItem(id: ItemID, contentType: ItemContentType)
    func cancel()
    func toQuickSetup()
    func toPremiumPlanPrompt(itemsLimit: Int)
    
    @MainActor
    func toConfirmDelete() async -> Bool
}

protocol PasswordsFlowControlling: AnyObject {
    func toContentTypeSelection(sourceItem: UIBarButtonItem?)
    func toEditItem(itemID: ItemID)
    func toItemDetail(itemID: ItemID)
    func toURI(_ selectedURI: URL)
    func toAddTag()

    func selectItem(id: ItemID, contentType: ItemContentType)
    func cancel()

    func toQuickSetup()
    func toPremiumPlanPrompt(itemsLimit: Int)

    @MainActor
    func toConfirmDelete() async -> Bool
}

public final class PasswordsFlowController: FlowController {
    private weak var parent: PasswordsFlowControllerParent?
    private var autoFillEnvironment: AutoFillEnvironment?
    
    public static func setAsRoot(
        on navigationController: UINavigationController,
        parent: PasswordsFlowControllerParent,
        autoFillEnvironment: AutoFillEnvironment? = nil
    ) {
        let view = PasswordsViewController()
        let flowController = PasswordsFlowController(viewController: view)
        flowController.parent = parent
        flowController.autoFillEnvironment = autoFillEnvironment
        
        let interactor = ModuleInteractorFactory.shared.passwordInteractor()
        
        let presenter = PasswordsPresenter(
            autoFillEnvironment: autoFillEnvironment,
            flowController: flowController,
            interactor: interactor
        )
        view.presenter = presenter
        presenter.view = view

        navigationController.setViewControllers([view], animated: false)
    }
}

extension PasswordsFlowController: PasswordsFlowControlling {

    func toContentTypeSelection(sourceItem: UIBarButtonItem?) {
        ContentTypeSelectionFlowController.present(
            on: viewController,
            parent: self,
            sourceItem: sourceItem
        )
    }

    func toEditItem(itemID: ItemID) {
        ItemEditorNavigationFlowController.present(
            on: viewController,
            parent: self,
            editItemID: itemID
        )
    }
    
    func toItemDetail(itemID: ItemID) {
        parent?.passwordsToItemDetail(itemID: itemID)
    }
    
    func toURI(_ selectedURI: URL) {
        UIApplication.shared.openInBrowser(selectedURI)
    }
    
    func selectItem(id: ItemID, contentType: ItemContentType) {
        parent?.selectItem(id: id, contentType: contentType)
    }
    
    func cancel() {
        parent?.cancel()
    }
    
    func toQuickSetup() {
        parent?.toQuickSetup()
    }
    
    @MainActor
    func toConfirmDelete() async -> Bool {
        await parent?.toConfirmDelete() ?? false
    }
    
    func toPremiumPlanPrompt(itemsLimit: Int) {
        parent?.toPremiumPlanPrompt(itemsLimit: itemsLimit)
    }

    @MainActor
    func toAddTag() {
        let editTagView = EditTagRouter.buildView(tagID: nil) { [weak self] in
            self?.viewController.dismiss(animated: true)
        }
        let hostingController = UIHostingController(rootView: editTagView)
        hostingController.modalPresentationStyle = .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.custom { _ in 300 }]
            sheet.prefersGrabberVisible = true
        }
        viewController.present(hostingController, animated: true)
    }
}

extension PasswordsFlowController {
    var viewController: PasswordsViewController { _viewController as! PasswordsViewController }
}

extension PasswordsFlowController: ItemEditorNavigationFlowControllerParent {

    func closeItemEditor(with result: SaveItemResult) {
        if result.isSuccess {
            viewController.presenter.handleRefresh()
        }
        viewController.dismiss(animated: true)
    }
}

extension PasswordsFlowController: ContentTypeSelectionFlowControllerParent {

    func contentTypeSelectionDidClose(with result: SaveItemResult) {
        if result.isSuccess {
            viewController.presenter.handleRefresh()
        }
        viewController.dismiss(animated: true)
    }

    func getAutoFillEnvironment() -> AutoFillEnvironment? {
        return autoFillEnvironment
    }
}
