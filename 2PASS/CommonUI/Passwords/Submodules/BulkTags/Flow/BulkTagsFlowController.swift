// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol BulkTagsFlowControllerParent: AnyObject {
    func bulkTagsDidCancel()
    func bulkTagsDidConfirmChanges(tagsToAdd: Set<ItemTagID>, tagsToRemove: Set<ItemTagID>)
}

final class BulkTagsFlowController: FlowController {
    private weak var parent: BulkTagsFlowControllerParent?

    static func present(
        on viewController: UIViewController,
        parent: BulkTagsFlowControllerParent,
        selectedItems: [ItemData]
    ) {
        let view = BulkTagsViewController()
        let flowController = BulkTagsFlowController(viewController: view)
        flowController.parent = parent

        let interactor = ModuleInteractorFactory.shared.bulkTagsModuleInteractor()
        let presenter = BulkTagsPresenter(
            flowController: flowController,
            interactor: interactor,
            selectedItems: selectedItems
        )
        view.presenter = presenter

        let navigationController = UINavigationController(rootViewController: view)
        flowController.configureSheet(for: navigationController)
        viewController.present(navigationController, animated: true)
    }
}

extension BulkTagsFlowController {
    var viewController: BulkTagsViewController { _viewController as! BulkTagsViewController }
}

extension BulkTagsFlowController: BulkTagsFlowControlling {
    func handleCancel() {
        parent?.bulkTagsDidCancel()
    }

    func handleConfirmChanges(_ changes: BulkTagChanges) {
        parent?.bulkTagsDidConfirmChanges(tagsToAdd: changes.tagsToAdd, tagsToRemove: changes.tagsToRemove)
    }
}

private extension BulkTagsFlowController {

    func configureSheet(for viewController: UIViewController) {
        guard let sheet = viewController.sheetPresentationController else { return }
        sheet.detents = [.large()]
        sheet.prefersGrabberVisible = true
    }
}
