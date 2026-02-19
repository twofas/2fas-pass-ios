// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import UserNotifications

extension MainRepositoryImpl {
    
    var pushNotificationToken: String? {
        _pushNotificationToken
    }
    
    func savePushNotificationToken(_ token: String?) {
        _pushNotificationToken = token
    }
    
    var isPushNotificationsEnabled: Bool {
        pushNotificationsPermissionsDataSource.isEnabled
    }
    
    var didPushNotificationsStatusChanged: NotificationCenter.Notifications {
        pushNotificationsPermissionsDataSource.didStatusChanged
    }
    
    @discardableResult func refreshPushNotificationsStatus() async -> Bool {
        await pushNotificationsPermissionsDataSource.refreshStatus()
    }
    
    var canRequestPushNotificationsPermissions: Bool {
        pushNotificationsPermissionsDataSource.canRequestPermissions
    }
    
    func requestPushNotificationsPermissions() async {
        await pushNotificationsPermissionsDataSource.requestPermissions()
    }

    func sendPushNotification(_ text: String) async {
        let content = UNMutableNotificationContent()
        content.body = text

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Log("Sending push notification failed: \(error)", module: .mainRepository, severity: .error)
        }
    }
}
