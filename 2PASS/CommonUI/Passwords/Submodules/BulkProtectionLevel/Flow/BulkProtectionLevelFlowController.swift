// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol BulkProtectionLevelFlowControllerParent: AnyObject {
    func bulkProtectionLevelDidCancel()
    func bulkProtectionLevelDidConfirmChange(to level: ItemProtectionLevel)
}

protocol BulkProtectionLevelFlowControlling: AnyObject {
    func handleCancel()
    func handleConfirmChange(_ level: ItemProtectionLevel)
    
    @MainActor
    func toConfirmChangeAlert(
        selectedCount: Int,
        source: UIBarButtonItem
    ) async -> Bool
}

final class BulkProtectionLevelFlowController: FlowController {
    private weak var parent: BulkProtectionLevelFlowControllerParent?
    
    static func present(
        on viewController: UIViewController,
        parent: BulkProtectionLevelFlowControllerParent,
        selectedItems: [ItemData],
        prefersDefaultSheetSize: Bool
    ) {
        let view = BulkProtectionLevelViewController()
        let flowController = BulkProtectionLevelFlowController(viewController: view)
        flowController.parent = parent
        let presenter = BulkProtectionLevelPresenter(flowController: flowController, selectedItems: selectedItems)
        view.presenter = presenter

        let navigationController = UINavigationController(rootViewController: view)
        flowController.configureSheet(for: navigationController, prefersDefaultSheetSize: prefersDefaultSheetSize)
        viewController.present(navigationController, animated: true)
    }
}

extension BulkProtectionLevelFlowController {
    var viewController: BulkProtectionLevelViewController { _viewController as! BulkProtectionLevelViewController }
}

extension BulkProtectionLevelFlowController: BulkProtectionLevelFlowControlling {
    func handleCancel() {
        parent?.bulkProtectionLevelDidCancel()
    }
    
    func handleConfirmChange(_ level: ItemProtectionLevel) {
        parent?.bulkProtectionLevelDidConfirmChange(to: level)
    }

    @MainActor
    func toConfirmChangeAlert(
        selectedCount: Int,
        source: UIBarButtonItem
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: nil,
                message: String(localized: .homeMultiselectSecurityTierChangeBody),
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(
                title: String(localized: .homeMultiselectSecurityTierChangeButton(Int32(selectedCount))),
                style: .default,
                handler: { _ in
                    continuation.resume(returning: true)
                }
            ))
            alert.addAction(UIAlertAction(title: String(localized: .commonCancel), style: .cancel, handler: { _ in
                continuation.resume(returning: false)
            }))
            alert.popoverPresentationController?.barButtonItem = source
            viewController.present(alert, animated: true)
        }
    }
}

private extension BulkProtectionLevelFlowController {
    
    enum Constants {
        static let sheetHeight: CGFloat = 340
    }

    func configureSheet(for navigationController: UINavigationController, prefersDefaultSheetSize: Bool) {
        guard let sheet = navigationController.sheetPresentationController else { return }

        // Where the sheet is presented as a form sheet (regular width and the iPad split column),
        // keep its default size instead of clamping to the compact-width preferred height.
        guard !prefersDefaultSheetSize else {
            sheet.prefersGrabberVisible = true
            return
        }

        let identifier = UISheetPresentationController.Detent.Identifier("bulkProtectionLevel")
        let detent = UISheetPresentationController.Detent.custom(identifier: identifier) { context in
            min(Constants.sheetHeight, context.maximumDetentValue)
        }
        sheet.detents = [detent]
        sheet.selectedDetentIdentifier = identifier
        sheet.prefersGrabberVisible = true
    }
}
