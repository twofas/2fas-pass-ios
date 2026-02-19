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
    var window: UIWindow?
    private var rootViewController: RootViewController?
    private let debugOverlay = DebugOverlay()
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard !ProcessInfo.isSwiftUIPreview else { return true }
        
        FirebaseApp.configure()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        rootViewController = RootFlowController.setAsRoot(
            in: window,
            parent: self
        )
                
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()
        
        rootViewController?.presenter.initialize()
        
        debugOverlay.initialize(window: window)
        
        Messaging.messaging().delegate = self
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        rootViewController?.presenter.applicationWillResignActive()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        rootViewController?.presenter.applicationDidEnterBackground()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        rootViewController?.presenter.applicationWillEnterForeground()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        rootViewController?.presenter.applicationDidBecomeActive()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        rootViewController?.presenter.applicationWillTerminate()
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        rootViewController?.presenter.applicationOpenURL(url) ?? false
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        rootViewController?.presenter.applicationContinueUserActivity(userActivity) ?? false
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
        rootViewController?.presenter.handleRemoteNotification(userInfo: userInfo)
    }
}

extension AppDelegate: RootFlowControllerParent {}

extension AppDelegate: MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        rootViewController?.presenter.handleDidReceiveRegistrationToken(fcmToken)
    }
}
