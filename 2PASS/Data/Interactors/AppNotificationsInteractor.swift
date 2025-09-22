// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol AppNotificationsInteracting: AnyObject {
    func fetchAppNotifications() async throws -> [AppNotification]
    func deleteAppNotification(_ notification: AppNotification) async throws
}

final class AppNotificationsInteractor: AppNotificationsInteracting {
    
    private let mainRepository: MainRepository
    private let connectInteractor: ConnectInteracting
    
    init(
        mainRepository: MainRepository,
        connectInteractor: ConnectInteracting
    ) {
        self.mainRepository = mainRepository
        self.connectInteractor = connectInteractor
    }
    
    func fetchAppNotifications() async throws -> [AppNotification] {
        let appNotifications = try await mainRepository.appNotifications()
        
        if let minimalVersion = appNotifications.compatibility?.minimalIosVersion {
            mainRepository.setMinimalAppVersionSupported(minimalVersion)
        }
        
        var validNotifications: [AppNotification] = []
        for notification in appNotifications.notifications ?? [] {
            let isValid = await connectInteractor.validateNotification(notification)
            if isValid, notification.expiresAt.timeIntervalSince(mainRepository.currentDate) > Config.Connect.notificationExpiryOffset {
                validNotifications.append(notification)
            }
        }
        
        return validNotifications
    }
    
    func deleteAppNotification(_ notification: AppNotification) async throws {
        try await mainRepository.deleteAppNotification(id: notification.id)
    }
}
