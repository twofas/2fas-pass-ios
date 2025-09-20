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
    static let cover = UIWindow.Level.normal + 3
    static let login = UIWindow.Level.normal + 2
    static let appNotifications = UIWindow.Level.normal + 1
    static let toasts = UIWindow.Level.alert
}

protocol RootFlowControllerParent: AnyObject {}

protocol RootFlowControlling: AnyObject {
    func toCover()
    func toOnboarding()
    func toEnterPassword()
    func toEnterWords()
    func toMain()
    func toLogin(coldRun: Bool)
    func toStorageError(error: String)
    func toRemoveCover(animated: Bool)
    func toRemoveLogin(animated: Bool)
    func toDismissKeyboard()
    func toAppNotification(_ notification: AppNotification)
    func toOpenExternalFileError()
}

final class RootFlowController: FlowController {
    private weak var parent: RootFlowControllerParent?
    private weak var coverViewController: UIViewController?
    private weak var loginViewController: LoginViewController?
    private weak var window: UIWindow?
    private let appNotificationsPresenter = AppNotificationsPresenter(windowLevel: .appNotifications)
    
    private let coverWindow: UIWindow = {
        let window = UIWindow()
        window.windowLevel = .cover
        window.backgroundColor = .clear
        return window
    }()
    
    private let loginWindow: UIWindow = {
        let window = UIWindow()
        window.windowLevel = .login
        window.backgroundColor = .clear
        return window
    }()
        
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
        coverViewController = vc
        coverWindow.addSubview(vc.view)
        vc.view.pinToParent()
        coverWindow.isHidden = false
    }
    
    func toEnterPassword() {
        activeViewController = LoginRestoreFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toOnboarding() {
        activeViewController = OnboardingFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toMain() {
        guard mainViewController == nil else { return }
        mainViewController = MainFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toLogin(coldRun: Bool) {
        toRemoveCover(animated: true)
        guard loginViewController == nil else { return }
                
        let loginViewController = LoginFlowController.setAsCover(
            in: loginWindow,
            coldRun: coldRun,
            parent: self
        )
        
        self.loginViewController = loginViewController
        loginWindow.isHidden = false
        loginWindow.makeKeyAndVisible()
    }
    
    func toStorageError(error: String) {
        let alert = UIAlertController(title: T.commonError.localized, message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: T.commonOk.localized, style: .cancel, handler: nil))
        viewController.present(alert, animated: false, completion: nil)
    }
    
    func toRemoveLogin(animated: Bool) {
        guard loginViewController != nil else { return }
        guard animated else {
            removeLogin()
            return
        }
        UIView.animate(withDuration: Animation.duration, delay: 0, options: .curveEaseInOut) {
            self.loginViewController?.view.alpha = 0
        } completion: { _ in
            self.removeLogin()
        }
    }
    
    func toRemoveCover(animated: Bool) {
        guard coverViewController != nil else { return }
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
    
    func toOpenExternalFileError() {
        let alert = UIAlertController(title: T.commonError, message: T.openExternalFileErrorBody, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: T.commonOk, style: .cancel, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
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
        window?.makeKeyAndVisible()
    }
}

extension RootFlowController: LoginFlowControllerParent {
    func loginSuccessful() {
        removeLogin()
        viewController.presenter.handleUserWasLoggedIn()
    }
    
    private func removeLogin() {
        loginViewController?.view.removeFromSuperview()
        loginViewController = nil
        loginWindow.isHidden = true
        window?.makeKeyAndVisible()
    }
}
