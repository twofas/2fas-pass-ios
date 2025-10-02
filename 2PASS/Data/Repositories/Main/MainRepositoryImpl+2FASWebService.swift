// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension MainRepositoryImpl {
    
    func appNotifications() async throws -> AppNotifications {
        guard let deviceID else {
            return AppNotifications(notifications: nil, compatibility: nil)
        }
        return try await twoFASWebServiceSession.fetchNotifications(forDeviceId: deviceID)
    }
    
    func deleteAppNotification(id: String) async throws {
        guard let deviceID else {
            return
        }
        try await twoFASWebServiceSession.deleteNotification(id: id, deviceId: deviceID)
    }
}
