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
    func toRestoreVault()
    func toMain()
    func toLogin(coldRun: Bool)
    func toStorageError(error: String)
    func toRemoveCover()
    func toRemoveLogin()
    func toDismissKeyboard()
    func toAppNotification(_ notification: AppNotification)
    func toOpenExternalFileError()
    func toUpdateAppForNewSyncScheme(schemaVersion: Int)
    func toUpdateAppForUnsupportedVersion(minimalVersion: String)
}

final class RootFlowController: FlowController {
    private weak var parent: RootFlowControllerParent?
    private weak var loginViewController: LoginViewController?
    private weak var window: UIWindow?
    private let appNotificationsPresenter = AppNotificationsPresenter(windowLevel: .appNotifications)
    
    private let coverWindow: UIWindow = {
        let window = UIWindow()
        window.windowLevel = .cover
        window.backgroundColor = .clear
        let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil)
        window.rootViewController = storyboard.instantiateViewController(withIdentifier: "LaunchScreen")
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
        coverWindow.isHidden = false
        coverWindow.makeKeyAndVisible()
    }
    
    func toEnterPassword() {
        activeViewController = LoginRestoreFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toOnboarding() {
        activeViewController = OnboardingFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toMain() {
        guard mainViewController == nil else {
            mainViewController?.viewDidAppear(false)
            return
        }
        mainViewController = MainFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toLogin(coldRun: Bool) {
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
    
    func toRemoveLogin() {
        guard loginViewController != nil else { return }
        UIView.animate(
            withDuration: Animation.duration,
            delay: 0,
            options:  [.curveEaseInOut, .beginFromCurrentState]
        ) {
            self.loginViewController?.view.alpha = 0
        } completion: { _ in
            self.removeLogin()
        }
    }
    
    func toRemoveCover() {
        coverWindow.rootViewController = nil
        coverWindow.removeFromSuperview()
        coverWindow.isHidden = true
    }
    
    func toDismissKeyboard() {
        loginWindow.endEditing(true)
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
    
    func toRestoreVault() {
        activeViewController = RestoreVaultFlowController.embedAsRoot(in: viewController, parent: self)
    }
    
    func toAppNotification(_ notification: AppNotification) {
        appNotificationsPresenter.present(notification)
    }
    
    func toOpenExternalFileError() {
        let alert = UIAlertController(title: T.commonError, message: T.openExternalFileErrorBody, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: T.commonOk, style: .cancel, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
    
    func toUpdateAppForNewSyncScheme(schemaVersion: Int) {
        let alert = UIAlertController(
            title: T.appUpdateModalTitle,
            message: T.cloudSyncInvalidSchemaErrorMsg(schemaVersion),
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

extension RootFlowController: RestoreVaultFlowControllerParent {

    func restoreVaultClose() {
        clearActiveViewController()
        viewController.presenter.handleWordsEntered()
    }
}

extension RootFlowController: MainFlowControllerParent {}

extension RootFlowController: LoginFlowControllerParent {
    func loginSuccessful() {
        viewController.presenter.handleUserWasLoggedIn()
    }
    
    private func removeLogin() {
        loginViewController?.view.removeFromSuperview()
        loginViewController = nil
        loginWindow.endEditing(true)
        loginWindow.isHidden = true
        loginWindow.rootViewController = nil
        window?.makeKeyAndVisible()
    }
}
