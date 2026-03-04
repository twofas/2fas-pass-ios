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
}

protocol PasswordsFlowControlling: AnyObject {
    func toContentTypeSelection(sourceItem: UIBarButtonItem?)
    func toEditItem(itemID: ItemID)
    func toItemDetail(itemID: ItemID)
    func toURI(_ selectedURI: URL)
    func toBulkProtectionLevelSelection(selectedItems: [ItemData])
    func toBulkTagsSelection(selectedItems: [ItemData])

    func selectItem(id: ItemID, contentType: ItemContentType)
    func cancel()

    func toQuickSetup()
    func toPremiumPlanPrompt(itemsLimit: Int)

    @MainActor
    func toConfirmDelete() async -> Bool

    @MainActor
    func toConfirmMultiselectDelete(selectedCount: Int, source: UIBarButtonItem?) async -> Bool
}

public final class PasswordsFlowController: FlowController {
    private weak var parent: PasswordsFlowControllerParent?
    private var autoFillEnvironment: AutoFillEnvironment?
    private var bulkProtectionLevelItemIDs: [ItemID] = []
    private var bulkTagsItemIDs: [ItemID] = []
    
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
        if shouldCreateLoginDirectly {
            presentLoginEditor()
            return
        }

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
    
    func toBulkProtectionLevelSelection(selectedItems: [ItemData]) {
        bulkProtectionLevelItemIDs = selectedItems.map(\.id)
        BulkProtectionLevelFlowController.present(
            on: viewController,
            parent: self,
            selectedItems: selectedItems
        )
    }

    func toBulkTagsSelection(selectedItems: [ItemData]) {
        bulkTagsItemIDs = selectedItems.map(\.id)
        BulkTagsFlowController.present(
            on: viewController,
            parent: self,
            selectedItems: selectedItems
        )
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
        guard autoFillEnvironment == nil else { return false }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: String(localized: .loginDeleteConfirmTitle),
                message: String(localized: .loginDeleteConfirmBody),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: String(localized: .commonYes), style: .destructive, handler: { _ in
                continuation.resume(returning: true)
            }))
            alert.addAction(UIAlertAction(title: String(localized: .commonNo), style: .cancel, handler: { _ in
                continuation.resume(returning: false)
            }))
            viewController.present(alert, animated: true, completion: nil)
        }
    }

    @MainActor
    func toConfirmMultiselectDelete(selectedCount: Int, source: UIBarButtonItem?) async -> Bool {
        guard autoFillEnvironment == nil else { return false }
        return await withCheckedContinuation { continuation in
            let title = String(localized: .homeMultiselectDeleteButton(Int32(selectedCount)))
            let alert = UIAlertController(
                title: nil,
                message: String(localized: .homeMultiselectDeleteBody),
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: title, style: .destructive, handler: { _ in
                continuation.resume(returning: true)
            }))
            alert.addAction(UIAlertAction(title: String(localized: .commonCancel), style: .cancel, handler: { _ in
                continuation.resume(returning: false)
            }))
            if let source {
                alert.popoverPresentationController?.barButtonItem = source
            }
            viewController.present(alert, animated: true, completion: nil)
        }
    }
    
    func toPremiumPlanPrompt(itemsLimit: Int) {
        parent?.toPremiumPlanPrompt(itemsLimit: itemsLimit)
    }

    private var shouldCreateLoginDirectly: Bool {
        guard let autoFillEnvironment else { return false }
        return autoFillEnvironment.isTextToInsert == false
    }

    private func presentLoginEditor() {
        guard let autoFillEnvironment else { return }

        let changeRequest = LoginDataChangeRequest(
            uris: autoFillEnvironment.serviceIdentifiers.map { .init(uri: $0, match: .domain) }
        )

        ItemEditorNavigationFlowController.present(
            on: viewController,
            parent: self,
            editItemID: nil,
            changeRequest: changeRequest
        )
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

extension PasswordsFlowController: BulkProtectionLevelFlowControllerParent {
    func bulkProtectionLevelDidCancel() {
        bulkProtectionLevelItemIDs = []
        viewController.dismiss(animated: true)
    }

    func bulkProtectionLevelDidConfirmChange(to level: ItemProtectionLevel) {
        let itemIDs = bulkProtectionLevelItemIDs
        bulkProtectionLevelItemIDs = []
        viewController.dismiss(animated: true)
        viewController.presenter.applyProtectionLevel(level, to: itemIDs)
    }
}

extension PasswordsFlowController: BulkTagsFlowControllerParent {
    func bulkTagsDidCancel() {
        bulkTagsItemIDs = []
        viewController.dismiss(animated: true)
    }

    func bulkTagsDidConfirmChanges(tagsToAdd: Set<ItemTagID>, tagsToRemove: Set<ItemTagID>) {
        let itemIDs = bulkTagsItemIDs
        bulkTagsItemIDs = []
        viewController.dismiss(animated: true)
        viewController.presenter.applyTagChanges(to: itemIDs, tagsToAdd: tagsToAdd, tagsToRemove: tagsToRemove)
    }
}
