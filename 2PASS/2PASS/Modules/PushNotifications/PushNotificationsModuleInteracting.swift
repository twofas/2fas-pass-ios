// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import UIKit.UIApplication

protocol PushNotificationsModuleInteracting {
    var isEnabled: Bool { get }
    
    var canRequestForPermissions: Bool { get }
    var didStatusChanged: NotificationCenter.Notifications { get }
    
    var systemSettingsURL: URL? { get }
    
    func requestForPermissions() async
}

final class PushNotificationsModuleInteractor: PushNotificationsModuleInteracting {
    
    private let pushNotificationsPermissionInteractor: PushNotificationsPermissionInteracting
    
    init(pushNotificationsPermissionInteractor: PushNotificationsPermissionInteracting) {
        self.pushNotificationsPermissionInteractor = pushNotificationsPermissionInteractor
    }
    
    var didStatusChanged: NotificationCenter.Notifications {
        pushNotificationsPermissionInteractor.didStatusChanged
    }
    
    var isEnabled: Bool {
        pushNotificationsPermissionInteractor.isEnabled
    }
    
    var canRequestForPermissions: Bool {
        pushNotificationsPermissionInteractor.canRequestForPermissions
    }
    
    var systemSettingsURL: URL? {
        URL(string: UIApplication.openNotificationSettingsURLString)
    }
    
    func requestForPermissions() async {
        await pushNotificationsPermissionInteractor.requestForPermissions()
    }
}
