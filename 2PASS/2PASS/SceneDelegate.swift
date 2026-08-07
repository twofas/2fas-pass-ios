// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CommonUI

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private(set) var rootViewController: RootViewController?
    private let debugOverlay = DebugOverlay()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard !ProcessInfo.isSwiftUIPreview else { return }
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let rootViewController = RootFlowController.setAsRoot(in: window, parent: self)
        self.rootViewController = rootViewController

        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        WindowSizeClasses.shared.startObserving(window)

        rootViewController.presenter.initialize()

        debugOverlay.initialize(window: window)

        if let url = connectionOptions.urlContexts.first?.url {
            _ = rootViewController.presenter.applicationOpenURL(url)
        }
        if let userActivity = connectionOptions.userActivities.first {
            _ = rootViewController.presenter.applicationContinueUserActivity(userActivity)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        rootViewController?.presenter.applicationWillResignActive()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        rootViewController?.presenter.applicationDidEnterBackground()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        rootViewController?.presenter.applicationWillEnterForeground()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        rootViewController?.presenter.applicationDidBecomeActive()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        rootViewController?.presenter.applicationWillTerminate()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        _ = rootViewController?.presenter.applicationOpenURL(url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        _ = rootViewController?.presenter.applicationContinueUserActivity(userActivity)
    }
}

extension SceneDelegate: RootFlowControllerParent {}
