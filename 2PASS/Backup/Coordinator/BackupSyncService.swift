// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Discriminator for backup-sync backend services. Each registered backend pairs this with a
/// `UUID` instance id (see `BackupSynchronizing.id` / `BackupConfigEntry.id`); together they
/// uniquely identify a service across launches.
public enum BackupSyncService: String, Hashable, Sendable, Codable {
    case webDAV
    case s3
    case iCloud
}

public struct BackupSyncOutcome: Equatable, Sendable {
    public let appliedRemoteChanges: Bool

    public init(appliedRemoteChanges: Bool) {
        self.appliedRemoteChanges = appliedRemoteChanges
    }
}
