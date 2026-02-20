// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

protocol ItemDetailFlowControllerParent: AnyObject {
    func itemDetailClose()
    
    @available(iOS 18.0, *)
    func itemDetailAutoFillTextToInsert(_ text: String)
}

protocol ItemDetailFlowControlling: AnyObject {
    func toEdit(_ itemID: ItemID)
    func toOpenURI(_ url: URL)
    func toWiFiNetworkQRCode(ssid: String, payload: String)
    func close()
    
    @available(iOS 18.0, *)
    func autoFillTextToInsert(_ text: String)
}

final class ItemDetailFlowController: FlowController {
    private weak var parent: ItemDetailFlowControllerParent?
    private var completion: ((ItemProtectionLevel) -> Void)?
    
    static func push(
        on navigationController: UINavigationController,
        parent: ItemDetailFlowControllerParent,
        itemID: ItemID,
        autoFillEnvironment: AutoFillEnvironment? = nil
    ) {
        let view = ItemDetailViewController()
        view.hidesBottomBarWhenPushed = navigationController.traitCollection.horizontalSizeClass == .compact
        let flowController = ItemDetailFlowController(viewController: view)
        flowController.parent = parent
        let interactor = ModuleInteractorFactory.shared.itemDetailInteractor()

        let presenter = ItemDetailPresenter(
            itemID: itemID,
            flowController: flowController,
            interactor: interactor,
            autoFillEnvironment: autoFillEnvironment
        )
        view.presenter = presenter

        navigationController.pushViewController(view, animated: true)
    }
    
    var viewController: ItemDetailViewController {
        _viewController as! ItemDetailViewController
    }
}

extension ItemDetailFlowController: ItemDetailFlowControlling {
    func toEdit(_ itemID: ItemID) {
        ItemEditorNavigationFlowController.present(
            on: viewController,
            parent: self,
            editItemID: itemID
        )
    }
    
    func toOpenURI(_ url: URL) {
        UIApplication.shared.openInBrowser(url)
    }

    func toWiFiNetworkQRCode(ssid: String, payload: String) {
        let qrCodeViewController = UIHostingController(
            rootView: WiFiNetworkQRCodeRouter.buildView(ssid: ssid, payload: payload)
        )

        qrCodeViewController.isModalInPresentation = false
        if let sheet = qrCodeViewController.sheetPresentationController, UIDevice.isiPad == false {
            sheet.detents = [.medium()]
            sheet.selectedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
        }
        viewController.present(qrCodeViewController, animated: true)
    }
    
    func close() {
        parent?.itemDetailClose()
    }

    @available(iOS 18.0, *)
    func autoFillTextToInsert(_ text: String) {
        parent?.itemDetailAutoFillTextToInsert(text)
    }
}

extension ItemDetailFlowController: ItemEditorNavigationFlowControllerParent {
    func closeItemEditor(with result: SaveItemResult) {
        _viewController.dismiss(animated: true)
    }
}
