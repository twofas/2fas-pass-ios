// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common
import FirebaseCore
import FirebaseMessaging

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    private var rootPresenter: RootPresenter? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0.delegate as? SceneDelegate)?.rootViewController?.presenter }
            .first
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard !ProcessInfo.isSwiftUIPreview else { return true }

        FirebaseApp.configure()

        Messaging.messaging().delegate = self

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // MARK: - Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Log("App did register for Remote Notifications. Device Token: \(String(data: deviceToken, encoding: .utf8) ?? "<error>")")

        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Log("App failed to register for remote notifications: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Log("App received Remote Notification")
        rootPresenter?.handleRemoteNotification(userInfo: userInfo)
    }
}

extension AppDelegate: MessagingDelegate {

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        rootPresenter?.handleDidReceiveRegistrationToken(fcmToken)
    }
}
