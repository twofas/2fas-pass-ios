// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// `BackupSynchronizing` conformance for the iCloud (CloudKit) backend.
///
/// Thin adapter over the existing `CloudSync` singleton: every `performSync(...)` call maps
/// to a single `cloudSync.syncOnce(...)` pass. No duplication of sync logic — the adapter
/// only translates the protocol shape. On success it stamps `BackupSyncDateStore` so iCloud
/// participates in the same "last successful sync" record as the file-based backends, which
/// the coordinator uses to order services on each `syncAll`.
public final class CloudSyncAdapter: BackupSynchronizing, @unchecked Sendable {
    public let id: UUID
    public let kind: SyncServiceKind = .iCloud

    private let cloudSync: CloudSync
    private let dateStore: BackupSyncDateStore

    public init(id: UUID, cloudSync: CloudSync, dateStore: BackupSyncDateStore) {
        self.id = id
        self.cloudSync = cloudSync
        self.dateStore = dateStore
    }

    public func performSync(overwritingVault: Bool) async throws(BackupSyncError) -> BackupSyncOutcome {
        let outcome = try await cloudSync.syncOnce(overwritingVault: overwritingVault)
        dateStore.setLastSyncDate(Date(), for: id)
        return outcome
    }
}
