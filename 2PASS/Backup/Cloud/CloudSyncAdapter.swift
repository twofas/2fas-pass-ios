// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public final class CloudSyncAdapter: BackupSynchronizing, @unchecked Sendable {
    public let id: BackupConfig.ID
    public let kind: BackupSyncService = .iCloud

    private let cloudSync: CloudSync
    private let dateStore: BackupSyncDateStore

    public init(id: BackupConfig.ID, cloudSync: CloudSync, dateStore: BackupSyncDateStore) {
        self.id = id
        self.cloudSync = cloudSync
        self.dateStore = dateStore
    }

    public func performSync(
        overwritingVault: Bool,
        allowingAnyDeviceId: Bool
    ) async throws(BackupSyncError) -> BackupSyncOutcome {
        // Only `allowingAnyDeviceId` reaches `syncOnce`: it's what `Bridge.start` uses to
        // arm `setTakingOverVault(true)`, which in turn bypasses `MergeHandler`'s deviceID
        // mismatch check — exactly the iCloud counterpart of the file-based path's
        // `allowingAnyDeviceId || context.allowsMultiDeviceSync` gate. `overwritingVault`
        // has no iCloud-layer effect (CloudKit syncs always go through merge); it's only
        // used below to stamp the flag-clearing record so the awaiting-set bookkeeping
        // matches the caller's stated intent.
        let outcome = try await cloudSync.syncOnce(allowingAnyDeviceId: allowingAnyDeviceId)
        dateStore.setLastSyncDate(
            Date(),
            for: id,
            consumed: BackupSyncFlags(
                overwritingVault: overwritingVault,
                allowingAnyDeviceId: allowingAnyDeviceId
            )
        )
        return outcome
    }
}
