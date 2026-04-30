// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Common

/// Runs registered backup-sync backends through the convergence loop.
///
/// Holds the three shared collaborators (`context`, `vaultExporter`, `localMerger`) plus the
/// persistent config store, and materializes services on demand each time `syncAll` /
/// `sync(_:)` runs. Mutating the registered set is **not** the container's job — that's
/// `BackupSyncConfigsInteracting`'s domain. The container is purely an orchestrator over
/// whatever configs the store currently holds.
///
/// Each `syncAll` / `sync` call freshly loads configs, rebuilds services, and constructs a
/// fresh `BackupSyncSession` to run them. `FileBasedSyncService` is a cheap struct; rebuild
/// cost is dominated by the configStore's decrypt+decode, which happens at most once per
/// orchestration call.
///
/// **In-progress guard.** `syncAll` and `sync(_:)` debounce overlapping triggers via an unfair
/// lock — while a sync is in flight, additional invocations return immediately (`syncAll` → `[]`,
/// `sync(_:)` → `.failure(.cancelled)`) instead of chaining behind the in-flight work. This stops
/// e.g. a periodic refresh from queueing up behind a user-initiated `Sync Now`. Cross-trigger
/// serialization is *only* this debounce — the session itself is single-use, with no internal
/// task chain.
public final class BackupSyncContainer: @unchecked Sendable {

    private let configStore: BackupSyncConfigStore
    private let dateStore: BackupSyncDateStore
    private let context: BackupSyncContext
    private let vaultExporter: BackupVaultExporting
    private let localMerger: BackupLocalMerging
    private let cloudSync: CloudSync
    private let isSyncing = OSAllocatedUnfairLock(initialState: false)

    public init(
        configStore: BackupSyncConfigStore,
        dateStore: BackupSyncDateStore,
        context: BackupSyncContext,
        vaultExporter: BackupVaultExporting,
        localMerger: BackupLocalMerging,
        cloudSync: CloudSync
    ) {
        self.configStore = configStore
        self.dateStore = dateStore
        self.context = context
        self.vaultExporter = vaultExporter
        self.localMerger = localMerger
        self.cloudSync = cloudSync
    }

    // MARK: - Sync (each call builds a fresh BackupSyncSession)

    @discardableResult
    public func syncAll(
        overwritingVault: Bool = false,
        onEvent: BackupSyncSession.ProgressHandler? = nil
    ) async -> [BackupSyncSession.SyncResult] {
        guard acquireSyncSlot() else {
            Log("BackupSyncContainer - syncAll ignored: sync already in progress", module: .backup)
            return []
        }
        defer { releaseSyncSlot() }
        let session = BackupSyncSession(
            services: currentServices(),
            overwritingVault: overwritingVault,
            lastSyncDate: { [dateStore] id in dateStore.lastSyncDate(for: id) },
            onEvent: onEvent
        )
        return await session.run()
    }

    @discardableResult
    public func sync(
        _ id: UUID,
        overwritingVault: Bool = false,
        onEvent: BackupSyncSession.ProgressHandler? = nil
    ) async -> Result<BackupSyncOutcome, BackupSyncError>? {
        guard let service = currentServices().first(where: { $0.id == id }) else { return nil }
        guard acquireSyncSlot() else {
            Log("BackupSyncContainer - sync ignored: sync already in progress", module: .backup)
            return .failure(.cancelled)
        }
        defer { releaseSyncSlot() }
        let session = BackupSyncSession(
            services: [service],
            overwritingVault: overwritingVault,
            lastSyncDate: { [dateStore] id in dateStore.lastSyncDate(for: id) },
            onEvent: onEvent
        )
        return await session.run().first?.outcome
    }

    // MARK: - Internals

    /// Atomic check-and-set: returns `true` if the slot was acquired (caller may run a sync),
    /// `false` if a sync is already in flight (caller must drop its trigger). The lock is held
    /// for the duration of the boolean flip — nanoseconds — never across the actual sync work.
    private func acquireSyncSlot() -> Bool {
        isSyncing.withLock { state in
            guard !state else { return false }
            state = true
            return true
        }
    }

    private func releaseSyncSlot() {
        isSyncing.withLock { $0 = false }
    }

    /// Materializes the live services from configs read fresh from the store. Order is taken
    /// directly from the persisted list — global registration order across kinds.
    private func currentServices() -> [any BackupSynchronizing] {
        configStore.loadConfigs().map { config in
            switch config {
            case .webDAV(let entry):
                makeService(
                    id: entry.id,
                    kind: .webDAV,
                    session: BackupWebDAVServiceSession(config: entry.config)
                )
            case .s3(let entry):
                makeService(
                    id: entry.id,
                    kind: .s3,
                    session: BackupS3ServiceSession(config: entry.config)
                )
            case .iCloud(let entry):
                CloudSyncAdapter(id: entry.id, cloudSync: cloudSync, dateStore: dateStore)
            }
        }
    }

    private func makeService(
        id: UUID,
        kind: SyncServiceKind,
        session: BackupFileServiceSession
    ) -> BackupFileSyncSession {
        BackupFileSyncSession(
            id: id,
            kind: kind,
            service: session,
            context: context,
            vaultExporter: vaultExporter,
            localMerger: localMerger,
            dateStore: dateStore
        )
    }
}
