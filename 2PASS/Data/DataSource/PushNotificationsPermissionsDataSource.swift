// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import UserNotifications
import UIKit.UIApplication

protocol PushNotificationsPermissionsDataSourcing: AnyObject {
    var isEnabled: Bool { get }
    var didStatusChanged: NotificationCenter.Notifications { get }
    
    var canRequestPermissions: Bool { get }
    func requestPermissions() async
    
    @discardableResult
    func refreshStatus() async -> Bool
}

final class PushNotificationsPermissionsDataSource: PushNotificationsPermissionsDataSourcing {

    private static let didChangeNotification = Notification.Name("PushNotificationsStatusDidChange")
    
    var didStatusChanged: NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: PushNotificationsPermissionsDataSource.didChangeNotification)
    }
    
    var isEnabled: Bool {
        authorizationStatus == .authorized
    }
    
    var canRequestPermissions: Bool {
        authorizationStatus == .notDetermined
    }
    
    private var authorizationStatus: UNAuthorizationStatus? {
        didSet {
            guard authorizationStatus != oldValue else {
                return
            }
            
            NotificationCenter.default.post(name: PushNotificationsPermissionsDataSource.didChangeNotification, object: nil)
        }
    }
    
    private let store = UNUserNotificationCenter.current()
    
    private var didBecomeActiveObserver: Task<Void, Never>?
    
    init() {
        Task {
            await refreshStatus()
        }
        
        didBecomeActiveObserver = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                await self?.refreshStatus()
            }
        }
    }
    
    deinit {
        didBecomeActiveObserver?.cancel()
    }
    
    @discardableResult
    func refreshStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        Task { @MainActor in
            self.authorizationStatus = settings.authorizationStatus
        }
        return settings.authorizationStatus == .authorized
    }
    
    func requestPermissions() async {
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            await refreshStatus()
        } catch {
            Log("Request for push notifications permissions failed: \(error)")
        }
    }
}
