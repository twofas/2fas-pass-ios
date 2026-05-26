// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol BackupSynchronizing: Sendable {
    var id: BackupConfig.ID { get }
    var kind: BackupSyncService { get }
    func performSync(overwritingVault: Bool, allowingAnyDeviceId: Bool) async throws(BackupSyncError) -> BackupSyncOutcome
}
