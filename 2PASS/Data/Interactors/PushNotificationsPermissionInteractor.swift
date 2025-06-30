// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UserNotifications

public protocol PushNotificationsPermissionInteracting: AnyObject {
    var isEnabled: Bool { get }
    var canRequestForPermissions: Bool { get }
    var didStatusChanged: NotificationCenter.Notifications { get }
    
    func requestForPermissions() async
}

final class PushNotificationsPermissionInteractor: PushNotificationsPermissionInteracting {
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    var isEnabled: Bool {
        mainRepository.isPushNotificationsEnabled
    }
    
    var canRequestForPermissions: Bool {
        mainRepository.canRequestPushNotificationsPermissions
    }
    
    func requestForPermissions() async {
        await mainRepository.requestPushNotificationsPermissions()
    }
    
    var didStatusChanged: NotificationCenter.Notifications {
        mainRepository.didPushNotificationsStatusChanged
    }
}
