// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum BackupSyncStatus: Sendable {
    case started
    case retrying(reason: String?)
    case succeeded
    case failed(BackupSyncError)
}

public struct BackupSyncActivity: Sendable, Equatable {
    public let isRunning: Bool
    public let activeConfigIDs: Set<UUID>

    public init(isRunning: Bool, activeConfigIDs: Set<UUID>) {
        self.isRunning = isRunning
        self.activeConfigIDs = activeConfigIDs
    }

    public static let idle = BackupSyncActivity(isRunning: false, activeConfigIDs: [])
}

public extension Notification.Name {
    static let backupSyncActivityChanged = Notification.Name("backupSyncActivityChanged")
    /// Posted when a `BackupSyncSession` finishes and at least one service reported
    /// `BackupSyncOutcome.appliedRemoteChanges == true`. Distinct from `.backupSyncActivityChanged`
    /// (which fires on every activity transition, including no-op finishes): this notification
    /// fires only when remote content was actually merged into the local database, making it the
    /// right edge for view layers that want to refresh their data.
    static let backupSyncDidApplyRemoteChanges = Notification.Name("backupSyncDidApplyRemoteChanges")
}
