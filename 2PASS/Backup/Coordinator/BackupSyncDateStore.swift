// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct BackupSyncFlags: Sendable {
    public let overwritingVault: Bool
    public let allowingAnyDeviceId: Bool

    public init(overwritingVault: Bool, allowingAnyDeviceId: Bool) {
        self.overwritingVault = overwritingVault
        self.allowingAnyDeviceId = allowingAnyDeviceId
    }
}

public protocol BackupSyncDateStore: Sendable {
    func lastSyncDate(for id: BackupConfig.ID) -> Date?

    func setLastSyncDate(_ date: Date, for id: BackupConfig.ID, consumed: BackupSyncFlags)
}
