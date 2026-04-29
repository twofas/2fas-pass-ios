// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol BackupSynchronizing: Sendable {
    /// Stable per-instance UUID; matches the id stored in the corresponding `BackupConfigEntry`.
    var id: UUID { get }
    /// Backend discriminator; redundant with the entry's `Config` type parameter on disk, but
    /// needed at runtime since the coordinator works with `[any BackupSynchronizing]`.
    var kind: SyncServiceKind { get }
    func performSync(overwritingVault: Bool) async throws(BackupSyncError) -> BackupSyncOutcome
}
