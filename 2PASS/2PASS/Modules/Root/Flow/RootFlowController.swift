// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Common
import CommonUI
import Data
import SwiftUI
import UIKit

extension UIWindow.Level {
    static let cover = UIWindow.Level.normal + 3
    static let login = UIWindow.Level.normal + 2
    static let appNotifications = UIWindow.Level.normal + 1
    static let toasts = UIWindow.Level.alert
    static let screenCaptureBlock = UIWindow.Level.alert + 10
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
    func setScreenCaptureBlocked(_ blocked: Bool)
    @available(iOS 26.0, *)
    @MainActor func toCredentialExchange(data: ASExportedCredentialData)
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

    private let screenCaptureBlockWindow: UIWindow = {
        let window = UIWindow()
        window.windowLevel = .screenCaptureBlock
        window.backgroundColor = .clear
        let viewController = UIViewController()
        viewController.view.backgroundColor = UIColor(resource: .mainBackground)
        window.rootViewController = viewController
        window.alpha = 0
        window.isHidden = true
        return window
    }()
        
    private var mainViewController: MainViewController?
    private var activeViewController: UIViewController?
    private var isScreenCaptureBlocked = false
    
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
        let alert = UIAlertController(title: String(localized: .commonError), message: error, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: .commonOk), style: .cancel, handler: nil))
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
        let alert = UIAlertController(title: String(localized: .commonError), message: String(localized: .openExternalFileErrorBody), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: .commonOk), style: .cancel, handler: nil))
        viewController.present(alert, animated: true, completion: nil)
    }
    
    func toUpdateAppForNewSyncScheme(schemaVersion: Int) {
        let alert = UIAlertController(
            title: String(localized: .appUpdateModalTitle),
            message: String(localized: .cloudSyncInvalidSchemaErrorMsg(Int32(schemaVersion))),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: String(localized: .appUpdateModalCtaNegative),
            style: .cancel,
            handler: nil
        ))
        
        alert.addAction(UIAlertAction(
            title: String(localized: .appUpdateModalCtaPositive),
            style: .default,
            handler: { _ in
                UIApplication.shared.open(Config.appStoreURL)
            }
        ))
        
        viewController.topViewController.present(alert, animated: true, completion: nil)
    }
    
    func toUpdateAppForUnsupportedVersion(minimalVersion: String) {        
        let alert = UIAlertController(
            title: String(localized: .appUpdateModalTitle),
            message: String(localized: .appUpdateModalSubtitle),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(
            title: String(localized: .appUpdateModalCtaNegative),
            style: .cancel,
            handler: nil
        ))
        
        alert.addAction(UIAlertAction(
            title: String(localized: .appUpdateModalCtaPositive),
            style: .default,
            handler: { _ in
                UIApplication.shared.open(Config.appStoreURL)
            }
        ))
        
        viewController.topViewController.present(alert, animated: true, completion: nil)
    }

    func setScreenCaptureBlocked(_ blocked: Bool) {
        guard blocked != isScreenCaptureBlocked else {
            return
        }

        isScreenCaptureBlocked = blocked
        blocked ? showScreenCaptureBlock() : hideScreenCaptureBlock()
    }

    @available(iOS 26.0, *)
    @MainActor func toCredentialExchange(data: ASExportedCredentialData) {
        let view = CredentialExchangeImportRouter.buildView(data: data, onClose: { [weak self] in
            self?.viewController.topViewController.dismiss(animated: true)
        })
        let hostingController = UIHostingController(rootView: view)
        hostingController.modalPresentationStyle = .fullScreen
        viewController.topViewController.present(hostingController, animated: true)
    }
}

private extension RootFlowController {

    func showScreenCaptureBlock() {
        guard let window else {
            return
        }

        screenCaptureBlockWindow.frame = window.bounds
        screenCaptureBlockWindow.windowScene = window.windowScene
        screenCaptureBlockWindow.alpha = 1
        screenCaptureBlockWindow.isHidden = false
    }

    func hideScreenCaptureBlock() {
        guard !screenCaptureBlockWindow.isHidden else {
            return
        }
        
        screenCaptureBlockWindow.alpha = 0
        screenCaptureBlockWindow.isHidden = true
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
