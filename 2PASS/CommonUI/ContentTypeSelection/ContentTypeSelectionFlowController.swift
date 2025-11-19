// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol ContentTypeSelectionFlowControllerParent: AnyObject {
    func contentTypeSelectionDidClose(with result: SaveItemResult)
    func getAutoFillEnvironment() -> AutoFillEnvironment?
}

protocol ContentTypeSelectionFlowControlling: AnyObject {
    func toItemEditor(contentType: ItemContentType)
    func close()
}

final class ContentTypeSelectionFlowController: FlowController {
    private weak var parent: ContentTypeSelectionFlowControllerParent?

    static func present(
        on viewController: UIViewController,
        parent: ContentTypeSelectionFlowControllerParent,
        sourceItem: (any UIPopoverPresentationControllerSourceItem)? = nil
    ) {
        let view = ContentTypeSelectionViewController()
        let flowController = ContentTypeSelectionFlowController(viewController: view)
        flowController.parent = parent

        view.flowController = flowController
        view.onSelect = { [weak flowController] contentType in
            flowController?.toItemEditor(contentType: contentType)
        }

        view.onClose = { [weak flowController] in
            flowController?.close()
        }

        if let sourceItem {
            view.modalPresentationStyle = .popover

            if let popover = view.popoverPresentationController {
                popover.sourceItem = sourceItem
                popover.delegate = view
            }
        }

        viewController.present(view, animated: true)
    }
}

extension ContentTypeSelectionFlowController: ContentTypeSelectionFlowControlling {
    func toItemEditor(contentType: ItemContentType) {
        let changeRequest: (any ItemDataChangeRequest)?
        let autoFillEnvironment = parent?.getAutoFillEnvironment()

        switch contentType {
        case .login:
            if let serviceIdentifiers = autoFillEnvironment?.serviceIdentifiers {
                changeRequest = LoginDataChangeRequest(uris: serviceIdentifiers.map { .init(uri: $0, match: .domain)} )
            } else {
                changeRequest = LoginDataChangeRequest(allowChangeContentType: true)
            }
        case .secureNote:
            changeRequest = SecureNoteDataChangeRequest(allowChangeContentType: true)
        case .unknown:
            changeRequest = nil
        }

        ItemEditorNavigationFlowController.present(
            on: viewController,
            parent: self,
            editItemID: nil,
            changeRequest: changeRequest
        )
    }

    func close() {
        parent?.contentTypeSelectionDidClose(with: .failure(.userCancelled))
    }
}

extension ContentTypeSelectionFlowController: ItemEditorNavigationFlowControllerParent {
    
    func closeItemEditor(with result: SaveItemResult) {
        parent?.contentTypeSelectionDidClose(with: result)
    }
}

extension ContentTypeSelectionFlowController {
    var viewController: ContentTypeSelectionViewController {
        _viewController as! ContentTypeSelectionViewController
    }
}
