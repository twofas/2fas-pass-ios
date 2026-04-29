// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Persistence port for backup sync configs.
///
/// `BackupSyncContainer` consumes this protocol to read configs at startup and write the full
/// per-kind list back when callers register or remove a backend. Conformers wrap their underlying
/// storage (e.g. encrypted UserDefaults) and serialize access internally — the container does
/// not coordinate concurrency between calls into this port.
///
/// **Multi-instance.** Each kind stores an *ordered list* of `(id, config)` entries. The order
/// is preserved across launches so the convergence loop runs services in a stable sequence.
/// Saves overwrite the full list per kind; conformers are not asked to do incremental updates.
///
/// Not declared `Sendable` deliberately: the production conformer is `MainRepositoryImpl`, a
/// singleton class with broad mutable state that does not safely satisfy `Sendable`. The
/// container holds the store inside its own concurrency boundary.
public protocol BackupSyncConfigStore: Sendable {
    /// Loads every persisted config in registration order. Returns `[]` if nothing is stored
    /// or the load fails.
    func loadConfigs() -> [BackupConfig]
    /// Overwrites the persisted list with `configs`. Saving an empty array clears persistence.
    func saveConfigs(_ configs: [BackupConfig])
}
