// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Runs registered backup-sync backends through the convergence loop.
///
/// Holds the three shared collaborators (`context`, `vaultExporter`, `localMerger`) plus the
/// persistent config store, and materializes services on demand each time `syncAll` /
/// `sync(_:)` runs. Mutating the registered set is **not** the container's job — that's
/// `BackupSyncConfigsInteracting`'s domain. The container is purely an orchestrator over
/// whatever configs the store currently holds.
///
/// Each `syncAll` / `sync` call freshly loads configs and rebuilds services. `FileBasedSyncService`
/// is a cheap struct; rebuild cost is dominated by the configStore's decrypt+decode, which
/// happens at most once per orchestration call.
public final class BackupSyncContainer: @unchecked Sendable {

    private let configStore: BackupSyncConfigStore
    private let dateStore: BackupSyncDateStore
    private let context: BackupSyncContext
    private let vaultExporter: BackupVaultExporting
    private let localMerger: BackupLocalMerging
    private let cloudSync: CloudSync
    private let coordinator: BackupSyncCoordinator

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
        self.coordinator = BackupSyncCoordinator()
    }

    // MARK: - Sync (async; touches coordinator actor)

    @discardableResult
    public func syncAll(overwritingVault: Bool = false) async -> [BackupSyncCoordinator.SyncResult] {
        await coordinator.syncAll(currentServices(), overwritingVault: overwritingVault)
    }

    @discardableResult
    public func sync(
        _ id: UUID,
        overwritingVault: Bool = false
    ) async -> Result<BackupSyncOutcome, BackupSyncError>? {
        guard let service = currentServices().first(where: { $0.id == id }) else { return nil }
        return await coordinator.sync(service, overwritingVault: overwritingVault)
    }

    // MARK: - Internals

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
                CloudSyncAdapter(id: entry.id, cloudSync: cloudSync)
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
