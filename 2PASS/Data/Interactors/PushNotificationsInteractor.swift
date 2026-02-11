// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol PushNotificationsInteracting: AnyObject {
    func send(_ text: String) async
}

final class PushNotificationsInteractor: PushNotificationsInteracting {
    private let mainRepository: MainRepository
    private let pushNotificationsPermissionInteractor: PushNotificationsPermissionInteracting

    init(
        mainRepository: MainRepository,
        pushNotificationsPermissionInteractor: PushNotificationsPermissionInteracting
    ) {
        self.mainRepository = mainRepository
        self.pushNotificationsPermissionInteractor = pushNotificationsPermissionInteractor
    }

    func send(_ text: String) async {
        guard pushNotificationsPermissionInteractor.isEnabled else {
            Log("Push notification skipped: notifications are not authorized", module: .autofill)
            return
        }

        await mainRepository.sendPushNotification(text)
    }
}
