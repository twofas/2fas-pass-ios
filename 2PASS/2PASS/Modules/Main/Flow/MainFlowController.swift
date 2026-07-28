// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import StoreKit
import CommonUI
import RevenueCatUI

protocol MainFlowControllerParent: AnyObject {}

protocol MainFlowControlling: AnyObject {
    func toQuickSetup()
    func toPayment()
    func toRequestEnableBiometry()
    func dismissRequestEnableBiometry()
    @MainActor func requestStoreReview()
}

final class MainFlowController: FlowController {
    private weak var parent: MainFlowControllerParent?
    private weak var biometricPromptViewController: UIViewController?
    private var splitFlowController: MainSplitFlowController?

    static func embedAsRoot(
        in viewController: UIViewController,
        parent: MainFlowControllerParent
    ) -> UIViewController {
        let interactor = ModuleInteractorFactory.shared.mainModuleInteracting()

        // A width-driven container hosts both representations: the sidebar split at wide widths and the
        // tab bar below the threshold (rendered as a floating top tab bar on iPadOS regular width).
        let container = MainContainerViewController()
        let flowController = MainFlowController(viewController: container)
        flowController.parent = parent

        let presenter = MainPresenter(
            flowController: flowController,
            interactor: interactor
        )
        container.presenter = presenter
        presenter.view = container

        // A single Passwords subtree (sidebar | list | detail) is built once and reparented between the
        // two layouts by the host coordinator, so the open item, its scroll position, and any modal it
        // presents survive a width-driven layout swap intact.
        let passwordsFilterState = PasswordsFilterState()
        let passwordsHost = PasswordsHostCoordinator(parent: flowController, filterState: passwordsFilterState)

        // Wide layout: the sidebar split. Its sidebar (primary) and detail (secondary) columns are fixed;
        // the list (supplementary) column is supplied by the host coordinator on attach.
        let split = MainSplitViewController(style: .tripleColumn)
        let coordinator = MainSplitFlowController(split: split, parent: flowController)
        flowController.splitFlowController = coordinator
        coordinator.start(subtree: passwordsHost.subtree)

        // A single Connect instance (camera, presenters) shared the same way: it lives in the Connect
        // tab slot in the narrow layout and is presented modally over the split in the wide one, so an
        // in-progress scan survives a width-driven layout swap.
        let connectHost = ConnectHostCoordinator(parent: flowController)

        // Narrow / middle layout: the tab bar (Passwords / Connect / Settings). The Passwords and
        // Connect slots start with placeholders; the host coordinators swap the shared instances into
        // them when the tab bar is the active layout, keeping the Settings (2) tab index stable.
        let tabBar = MainViewController()
        tabBar.addTab(passwordsHost.passwordsTabSlotPlaceholder)
        tabBar.addTab(connectHost.tabSlotPlaceholder)
        SettingsNavigationFlowController.showAsTab(in: tabBar, parent: flowController)

        passwordsHost.configure(split: split, tabBar: tabBar)
        connectHost.configure(tabBar: tabBar, container: container, splitCoordinator: coordinator)
        coordinator.connectHost = connectHost
        container.configure(
            split: split,
            tabBar: tabBar,
            splitCoordinator: coordinator,
            passwordsHost: passwordsHost,
            connectHost: connectHost
        )

        viewController.placeChild(container)

        return container
    }
}

extension MainFlowController: MainFlowControlling {
    func toPayment() {
        let controller = PaywallViewController(displayCloseButton: true) { controller in
            controller.dismiss(animated: true)
        }
        viewController.topViewController.present(controller, animated: true, completion: nil)
    }

    @MainActor
    func requestStoreReview() {
        guard let scene = viewController.view.window?.windowScene else { return }
        AppStore.requestReview(in: scene)
    }
}

extension MainFlowController {
    var viewController: UIViewController { _viewController }
}

extension MainFlowController: PasswordsNavigationFlowControllerParent {
    
    func toQuickSetup() {
        let quickSetupViewController = MainActor.assumeIsolated {
            UIHostingController(rootView: QuickSetupRouter.buildView())
        }
        quickSetupViewController.modalPresentationStyle = .formSheet
        quickSetupViewController.preferredContentSize = CGSize(width: 600, height: 760)
        viewController.present(quickSetupViewController, animated: true)
    }
    
    func toPremiumPlanPrompt(itemsLimit: Int) {
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
        
        viewController.present(controller, animated: true)
    }
    
    func toRequestEnableBiometry() {
        guard viewController.presentedViewController == nil else { return }

        let vc = UIHostingController(rootView: BiometricPromptRouter.buildView(onClose: { [weak self] in
            self?.dismissBiometricPrompt(animated: true)
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
        biometricPromptViewController = vc

        viewController.present(vc, animated: true)
    }

    func dismissRequestEnableBiometry() {
        dismissBiometricPrompt(animated: false)
    }

    private func dismissBiometricPrompt(animated: Bool) {
        guard let biometricPromptViewController else { return }
        biometricPromptViewController.dismiss(animated: animated)
        self.biometricPromptViewController = nil
    }
}

extension MainFlowController: ConnectNavigationFlowControllerParent {}
extension MainFlowController: SettingsNavigationFlowControllerParent {}
