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

    /// Presents the item editor for `itemID`. The detail delegates this to its parent instead of
    /// presenting it itself, because the editor must outlive the detail: on an iPad split→tab swap the
    /// shared list re-creates the detail (a `UIScrollView` can't move between two nav controllers), which
    /// deallocates the detail's flow controller. If that flow controller were the editor's (weak) parent,
    /// the close chain would break. The parent here is the long-lived subtree coordinator, so it both
    /// presents the editor on a swap survivor and stays alive to handle its dismissal.
    func itemDetailToEdit(_ itemID: ItemID)

    /// The view controller to present the detail's *self-dismissing* modals on (share link, Wi-Fi QR) —
    /// a host that stays in the window across an iPad layout swap. Unlike the editor these need no parent
    /// callback (they close themselves), so presenting from a survivor is enough; the detail column is
    /// discarded on split→tab, which would otherwise orphan them.
    func itemDetailModalPresenter() -> UIViewController

    @available(iOS 18.0, *)
    func itemDetailAutoFillTextToInsert(_ text: String)
}

protocol ItemDetailFlowControlling: AnyObject {
    func toEdit(_ itemID: ItemID)
    func toShareLink(_ itemID: ItemID)
    func toOpenURI(_ url: URL)
    func toWiFiNetworkQRCode(ssid: String, payload: String)
    func close()
    
    @available(iOS 18.0, *)
    func autoFillTextToInsert(_ text: String)
}

final class ItemDetailFlowController: FlowController {
    private weak var parent: ItemDetailFlowControllerParent?
    private var completion: ((ItemProtectionLevel) -> Void)?
    
    @discardableResult
    static func push(
        on navigationController: UINavigationController,
        parent: ItemDetailFlowControllerParent,
        itemID: ItemID,
        autoFillEnvironment: AutoFillEnvironment? = nil,
        animated: Bool = true
    ) -> ItemDetailViewController {
        let view = make(parent: parent, itemID: itemID, autoFillEnvironment: autoFillEnvironment)
        view.hidesBottomBarWhenPushed = navigationController.traitCollection.horizontalSizeClass == .compact
        navigationController.pushViewController(view, animated: animated)
        return view
    }

    static func makeDetailViewController(
        parent: ItemDetailFlowControllerParent,
        itemID: ItemID
    ) -> ItemDetailViewController {
        make(parent: parent, itemID: itemID, autoFillEnvironment: nil)
    }

    private static func make(
        parent: ItemDetailFlowControllerParent,
        itemID: ItemID,
        autoFillEnvironment: AutoFillEnvironment?
    ) -> ItemDetailViewController {
        let view = ItemDetailViewController()
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

        return view
    }
    
    var viewController: ItemDetailViewController {
        _viewController as! ItemDetailViewController
    }

    /// Host for the detail's self-dismissing modals (share link, Wi-Fi QR): the parent-provided swap
    /// survivor, falling back to the detail's own view controller. See `itemDetailModalPresenter`.
    private var modalPresenter: UIViewController {
        parent?.itemDetailModalPresenter() ?? _viewController
    }
}

extension ItemDetailFlowController: ItemDetailFlowControlling {
    func toEdit(_ itemID: ItemID) {
        // Delegated to the parent (the long-lived subtree coordinator) so the editor outlives this
        // detail — see `ItemDetailFlowControllerParent.itemDetailToEdit`.
        parent?.itemDetailToEdit(itemID)
    }

    func toShareLink(_ itemID: ItemID) {
        let shareLinkViewController = UIHostingController(
            rootView: ShareLinkItemRouter.buildView(itemID: itemID)
        )
        modalPresenter.present(shareLinkViewController, animated: true)
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
        modalPresenter.present(qrCodeViewController, animated: true)
    }
    
    func close() {
        parent?.itemDetailClose()
    }

    @available(iOS 18.0, *)
    func autoFillTextToInsert(_ text: String) {
        parent?.itemDetailAutoFillTextToInsert(text)
    }
}
