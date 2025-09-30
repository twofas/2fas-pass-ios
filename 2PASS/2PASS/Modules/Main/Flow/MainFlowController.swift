// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import CommonUI
import RevenueCatUI

protocol MainFlowControllerParent: AnyObject {}

protocol MainFlowControlling: AnyObject {
    func toQuickSetup()
    func toPayment()
    func toRequestEnableBiometry()
    func dismissRequestEnableBiometry()
}

final class MainFlowController: FlowController {
    private weak var parent: MainFlowControllerParent?
    private weak var biometricPromptViewController: UIViewController?
    
    static func embedAsRoot(
        in viewController: UIViewController,
        parent: MainFlowControllerParent
    ) -> MainViewController {
        let view = MainViewController()
        let flowController = MainFlowController(viewController: view)
        flowController.parent = parent
        
        let interactor = ModuleInteractorFactory.shared.mainModuleInteracting()
                
        let presenter = MainPresenter(
            flowController: flowController,
            interactor: interactor
        )
        view.presenter = presenter
        presenter.view = view
        
        PasswordsNavigationFlowController.showAsTab(in: view, parent: flowController)
        ConnectNavigationFlowController.showAsTab(in: view, parent: flowController)
        SettingsNavigationFlowController.showAsTab(in: view, parent: flowController)
        
        viewController.placeChild(view)
        
        return view
    }
}

extension MainFlowController: MainFlowControlling {
    func toPayment() {
        let controller = PaywallViewController(displayCloseButton: true) { [weak viewController] controller in
            viewController?.dismiss(animated: true)
        }
        viewController.topViewController.present(controller, animated: true, completion: nil)
    }
}

extension MainFlowController {
    var viewController: MainViewController { _viewController as! MainViewController }
}

extension MainFlowController: PasswordsNavigationFlowControllerParent {
    
    func toQuickSetup() {
        let quickSetupViewController = UIHostingController(rootView: QuickSetupRouter.buildView())
        viewController.present(quickSetupViewController, animated: true)
    }
    
    func toPremiumPlanPrompt(itemsLimit: Int) {
        let controller = UIHostingController(
            rootView: PremiumPromptRouter.buildView(
                title: Text(T.paywallNoticeItemsLimitReachedTitle.localizedKey),
                description: Text(T.paywallNoticeItemsLimitReachedMsg(itemsLimit))
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
        
        viewController.present(controller, animated: true)
    }
    
    func toRequestEnableBiometry() {
        guard viewController.presentedViewController == nil else { return }
        
        let vc = UIHostingController(rootView: BiometricPromptRouter.buildView(onClose: { [weak self] in
            self?.viewController.dismiss(animated: true)
        }))
        
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.custom(resolver: { context in
                if context.containerTraitCollection.userInterfaceIdiom == .phone {
                    return BiometricPromptViewConstants.sheetHeight
                } else {
                    return context.maximumDetentValue
                }
            })]
        }
        
        vc.isModalInPresentation = true
        biometricPromptViewController = viewController
        
        viewController.present(vc, animated: true)
    }
    
    func dismissRequestEnableBiometry() {
        guard biometricPromptViewController != nil else { return }
        biometricPromptViewController?.dismiss(animated: false)
        biometricPromptViewController = nil
    }
    
    @MainActor
    func toConfirmDelete() async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: T.loginDeleteConfirmTitle, message: T.loginDeleteConfirmBody, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: T.commonYes, style: .destructive, handler: { _ in
                continuation.resume(returning: true)
            }))
            alert.addAction(UIAlertAction(title: T.commonNo, style: .cancel, handler: { _ in
                continuation.resume(returning: false)
            }))
            viewController.present(alert, animated: true, completion: nil)
        }
    }
}

extension MainFlowController: ConnectNavigationFlowControllerParent {}
extension MainFlowController: SettingsNavigationFlowControllerParent {}
