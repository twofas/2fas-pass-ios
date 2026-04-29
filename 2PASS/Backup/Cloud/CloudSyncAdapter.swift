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
/// only translates the protocol shape.
public final class CloudSyncAdapter: BackupSynchronizing, @unchecked Sendable {
    public let id: UUID
    public let kind: SyncServiceKind = .iCloud

    private let cloudSync: CloudSync

    public init(id: UUID, cloudSync: CloudSync) {
        self.id = id
        self.cloudSync = cloudSync
    }

    public func performSync(overwritingVault: Bool) async throws(BackupSyncError) -> BackupSyncOutcome {
        try await cloudSync.syncOnce(overwritingVault: overwritingVault)
    }
}
