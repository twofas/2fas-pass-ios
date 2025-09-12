// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import Data
import CommonUI
import SwiftUI

extension UIWindow.Level {
    static let login = UIWindow.Level.normal + 2
    static let appNotifications = UIWindow.Level.normal + 1
    static let toasts = UIWindow.Level.alert
}

protocol RootFlowControllerParent: AnyObject {}

protocol RootFlowControlling: AnyObject {
    func toCover()
    func toVaultRecovery()
    func toEnterPassword()
    func toEnterWords()
    func toMain(immediately: Bool)
    func toLogin(coldRun: Bool, canUseBiometry: Bool)
    func toStorageError(error: String)
    func toRemoveCover(animated: Bool)
    func toDismissKeyboard()
    func toAppNotification(_ notification: AppNotification)
    func toRequestEnableBiometry()
    func toOpenExternalFileError()
    func toUpdateAppForNewSyncScheme(schemeVersion: Int, expectedSchemeVersion: Int)
    func toUpdateAppForUnsupportedVersion(minimalVersion: String)
}

final class RootFlowController: FlowController {
    private weak var parent: RootFlowControllerParent?
    private weak var coverViewController: LoginViewController?
    private weak var biometricPromptViewController: UIViewController?
    private weak var window: UIWindow?
    private let appNotificationsPresenter = AppNotificationsPresenter(windowLevel: .appNotifications)
    
    private let coverWindow: UIWindow = {
        let window = UIWindow()
        window.windowLevel = .login
        window.backgroundColor = .clear
        return window
    }()
    
    private var isLoginInCoverView = false
    
    private var mainViewController: MainViewController?
    private var activeViewController: UIViewController?
    
    static func setAsRoot(
        in window: UIWindow?,
        parent: RootFlowControllerParent
    ) -> RootViewController {
        let view = RootViewController()
        let flowController = RootFlowController(viewController: view)
        flowController.parent = parent
        flowController.window = window
        
        let interactor = ModuleInteractorFactory.shared.rootModuleInteractor()
        let presenter = RootPresenter(
            flowController: flowController,
            interactor: interactor
        )
        view.presenter = presenter
        
        window?.rootViewController = view
        
        return view
    }
}

extension RootFlowController {
    var viewController: RootViewController {
        _viewController as! RootViewController
    }
}

extension RootFlowController: RootFlowControlling {
    func toCover() {
        let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "LaunchScreen")
        guard let loginViewController = vc as? LoginViewController else { return }
        coverViewController = loginViewController
        window?.addSubview(loginViewController.view)
        loginViewController.view.pinToParent()
    }
    
    func toEnterPassword() {
        activeViewController = LoginRestoreFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toVaultRecovery() {
        activeViewController = OnboardingFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toMain(immediately: Bool) {
        // TODO: Add removing e.g. for login
        guard mainViewController == nil else { return }
        mainViewController = MainFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toLogin(coldRun: Bool, canUseBiometry: Bool) {
        guard !isLoginInCoverView else {
            if canUseBiometry {
                coverViewController?.presenter?.startBiometryIfAvailable()
            }
            return
        }
        
        if coverViewController != nil {
            removeCover()
        }
        
        biometricPromptViewController?.dismiss(animated: false)
        
        
        let coverViewController = LoginFlowController.setAsCover(
            in: coverWindow,
            coldRun: coldRun,
            parent: self
        )
        
        self.coverViewController = coverViewController
        isLoginInCoverView = true
        
        coverWindow.makeKeyAndVisible()
        
        if canUseBiometry {
            coverViewController.presenter.startBiometryIfAvailable()
        }
    }
    
    func toStorageError(error: String) {
        let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        viewController.present(alert, animated: false, completion: nil)
    }
    
    func toRemoveCover(animated: Bool) {
        guard animated else {
            removeCover()
            return
        }
        UIView.animate(withDuration: Animation.duration, delay: 0, options: .curveEaseInOut) {
            self.coverViewController?.view.alpha = 0
        } completion: { _ in
            self.removeCover()
        }
    }
    
    func toDismissKeyboard() {
        window?.endEditing(true)
    }
    
    func clearActiveViewController() {
        if let activeViewController {
            activeViewController.willMove(toParent: nil)
            activeViewController.view.removeFromSuperview()
            activeViewController.removeFromParent()
            activeViewController.didMove(toParent: nil)
            self.activeViewController = nil
        }
    }
    
    func toEnterWords() {
        activeViewController = EnterWordsFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toAppNotification(_ notification: AppNotification) {
        appNotificationsPresenter.present(notification)
    }
    
    func toRequestEnableBiometry() {
        guard mainViewController?.presentedViewController == nil else { return }
        
        let viewController = UIHostingController(rootView: BiometricPromptRouter.buildView(onClose: { [weak self] in
            self?.mainViewController?.dismiss(animated: true)
        }))
        
        if let sheet = viewController.sheetPresentationController {
            sheet.detents = [.custom(resolver: { context in
                if context.containerTraitCollection.userInterfaceIdiom == .phone {
                    return BiometricPromptViewConstants.sheetHeight
                } else {
                    return context.maximumDetentValue
                }
            })]
        }
        
        viewController.isModalInPresentation = true
        biometricPromptViewController = viewController
        
        mainViewController?.present(viewController, animated: true)
    }
    
    func toOpenExternalFileError() {
        let alert = UIAlertController(title: T.commonError, message: T.openExternalFileErrorBody, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: T.commonOk, style: .cancel, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
    
    func toUpdateAppForNewSyncScheme(schemeVersion: Int, expectedSchemeVersion: Int) {
        let alert = UIAlertController(
            title: T.appUpdateModalTitle,
            message: T.cloudSyncInvalidSchemaErrorMsg(schemeVersion),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: T.appUpdateModalCtaNegative,
            style: .cancel,
            handler: nil
        ))
        
        alert.addAction(UIAlertAction(
            title: T.appUpdateModalCtaPositive,
            style: .default,
            handler: { _ in
                UIApplication.shared.open(Config.appStoreURL)
            }
        ))
        
        viewController.topViewController.present(alert, animated: true, completion: nil)
    }
    
    func toUpdateAppForUnsupportedVersion(minimalVersion: String) {        
        let alert = UIAlertController(
            title: T.appUpdateModalTitle,
            message: T.appUpdateModalSubtitle,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: T.appUpdateModalCtaNegative,
            style: .cancel,
            handler: nil
        ))
        
        alert.addAction(UIAlertAction(
            title: T.appUpdateModalCtaPositive,
            style: .default,
            handler: { _ in
                UIApplication.shared.open(Config.appStoreURL)
            }
        ))
        
        viewController.topViewController.present(alert, animated: true, completion: nil)
    }
}

extension RootFlowController {
    func vaultRecoveryToLoggedIn() {
        clearActiveViewController()
        viewController.presenter.handleUserWasLoggedIn()
    }
}

extension RootFlowController: OnboardingNavigationFlowControllerParent {
    
    func onboardingToLoggedIn() {
        clearActiveViewController()
        viewController.presenter.handleUserWasLoggedIn()
    }
}

extension RootFlowController: LoginRestoreFlowControllerParent {
    func loginRestoreSuccessful() {
        clearActiveViewController()
        viewController.presenter.handleUserWasLoggedIn()
    }
    
    func loginRestoreAppReset() {
        clearActiveViewController()
        viewController.presenter.handleAppReset()
    }
}

extension RootFlowController {
    func recoveryKitClose() {
        clearActiveViewController()
        viewController.presenter.handleUserWasLoggedIn()
    }
}

extension RootFlowController: EnterWordsFlowControllerParent {
    func enterWordsToEnterMasterPassword(with entropy: Entropy, fileData: ExchangeVault) {
        // not used in this context
    }
    
    func enterWordsToEnterMasterPassword() {
        // not used in this context
    }
    
    func enterWordsToDecrypt(with masterKey: MasterKey, entropy: Entropy, fileData: ExchangeVault) {
        // not used in this context
    }
    
    func enterWordsClose() {
        clearActiveViewController()
        viewController.presenter.handleWordsEntered()
    }
}

extension RootFlowController: MainFlowControllerParent {
    func removeCover() {
        coverViewController?.view.removeFromSuperview()
        coverViewController = nil
        coverWindow.isHidden = true
        isLoginInCoverView = false
        window?.makeKeyAndVisible()
    }
}

extension RootFlowController: LoginFlowControllerParent {
    func loginSuccessful() {
        removeLogin()
        viewController.presenter.handleUserWasLoggedIn()
    }
    
    private func removeLogin() {
        // TODO: Remove VC!
        toRemoveCover(animated: true)
    }
}
