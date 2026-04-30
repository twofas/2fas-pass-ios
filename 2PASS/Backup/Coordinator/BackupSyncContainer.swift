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
    private struct State {
        var isSyncing = false
        var activeConfigIDs: Set<UUID> = []
        var cancelCurrentSync: (@Sendable () -> Void)?

        var activity: BackupSyncActivity {
            BackupSyncActivity(isRunning: isSyncing, activeConfigIDs: activeConfigIDs)
        }
    }

    private let servicesProvider: @Sendable () -> [any BackupSynchronizing]
    private let lastSyncDateProvider: @Sendable (UUID) -> Date?
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init(
        configStore: BackupSyncConfigStore,
        dateStore: BackupSyncDateStore,
        context: BackupSyncContext,
        vaultExporter: BackupVaultExporting,
        localMerger: BackupLocalMerging,
        cloudSync: CloudSync
    ) {
        servicesProvider = Self.makeServicesProvider(
            configStore: configStore,
            dateStore: dateStore,
            context: context,
            vaultExporter: vaultExporter,
            localMerger: localMerger,
            cloudSync: cloudSync
        )
        lastSyncDateProvider = { [dateStore] id in
            dateStore.lastSyncDate(for: id)
        }
    }

    init(
        servicesProvider: @escaping @Sendable () -> [any BackupSynchronizing],
        lastSyncDateProvider: @escaping @Sendable (UUID) -> Date? = { _ in nil }
    ) {
        self.servicesProvider = servicesProvider
        self.lastSyncDateProvider = lastSyncDateProvider
    }

    // MARK: - Sync (each call builds a fresh BackupSyncSession)

    public var currentActivity: BackupSyncActivity {
        state.withLock { $0.activity }
    }

    public func cancelCurrentSync() {
        let cancel = state.withLock { $0.cancelCurrentSync }
        cancel?()
    }

    public func syncAll(
        overwritingVault: Bool = false,
        onEvent: BackupSyncSession.ProgressHandler? = nil
    ) {
        _ = syncAllTask(overwritingVault: overwritingVault, onEvent: onEvent)
    }

    @discardableResult
    func syncAllTask(
        overwritingVault: Bool = false,
        onEvent: BackupSyncSession.ProgressHandler? = nil
    ) -> Task<[BackupSyncSession.SyncResult], Never>? {
        guard reserveSyncSlot() else {
            Log("BackupSyncContainer - syncAll ignored: sync already in progress", module: .backup)
            return nil
        }
        let session = BackupSyncSession(
            services: servicesProvider(),
            overwritingVault: overwritingVault,
            lastSyncDate: lastSyncDateProvider,
            onEvent: makeProgressHandler(adding: onEvent)
        )
        let task = Task {
            defer { self.clearSyncSlot() }
            return await session.run()
        }
        installCancellationHandler {
            task.cancel()
        }
        return task
    }

    @discardableResult
    public func sync(
        _ id: UUID,
        overwritingVault: Bool = false,
        onEvent: BackupSyncSession.ProgressHandler? = nil
    ) async -> Result<BackupSyncOutcome, BackupSyncError>? {
        guard let service = servicesProvider().first(where: { $0.id == id }) else { return nil }
        guard reserveSyncSlot() else {
            Log("BackupSyncContainer - sync ignored: sync already in progress", module: .backup)
            return .failure(.cancelled)
        }
        let session = BackupSyncSession(
            services: [service],
            overwritingVault: overwritingVault,
            lastSyncDate: lastSyncDateProvider,
            onEvent: makeProgressHandler(adding: onEvent)
        )
        let task = Task {
            await session.run().first?.outcome
        }
        installCancellationHandler {
            task.cancel()
        }
        defer { clearSyncSlot() }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: - Internals

    private func reserveSyncSlot() -> Bool {
        let shouldNotify = state.withLock { state in
            guard !state.isSyncing else { return false }
            state.isSyncing = true
            return true
        }
        if shouldNotify {
            postActivityChanged()
        }
        return shouldNotify
    }

    private func installCancellationHandler(
        _ cancelCurrentSync: @escaping @Sendable () -> Void
    ) {
        let shouldNotify = state.withLock { state in
            let previous = state.activity
            state.cancelCurrentSync = cancelCurrentSync
            return state.activity != previous
        }
        if shouldNotify {
            postActivityChanged()
        }
    }

    private func clearSyncSlot() {
        let shouldNotify = state.withLock { state in
            let previous = state.activity
            state.isSyncing = false
            state.activeConfigIDs.removeAll()
            state.cancelCurrentSync = nil
            return state.activity != previous
        }
        if shouldNotify {
            postActivityChanged()
        }
    }

    private func makeProgressHandler(
        adding downstream: BackupSyncSession.ProgressHandler?
    ) -> BackupSyncSession.ProgressHandler {
        { [weak self] event in
            self?.handle(event)
            downstream?(event)
        }
    }

    private func handle(_ event: BackupSyncSession.ProgressEvent) {
        let shouldNotify = state.withLock { state in
            let previous = state.activity
            switch event {
            case .started(let id, _):
                state.activeConfigIDs.insert(id)
            case .finished(let id, _, _):
                state.activeConfigIDs.remove(id)
            }
            return state.activity != previous
        }
        if shouldNotify {
            postActivityChanged()
        }
    }

    private func postActivityChanged() {
        NotificationCenter.default.post(name: .backupSyncActivityChanged, object: nil)
    }

    private static func makeServicesProvider(
        configStore: BackupSyncConfigStore,
        dateStore: BackupSyncDateStore,
        context: BackupSyncContext,
        vaultExporter: BackupVaultExporting,
        localMerger: BackupLocalMerging,
        cloudSync: CloudSync
    ) -> @Sendable () -> [any BackupSynchronizing] {
        {
            configStore.loadConfigs().map { config in
                switch config {
                case .webDAV(let entry):
                    Self.makeService(
                        id: entry.id,
                        kind: .webDAV,
                        session: BackupWebDAVServiceSession(config: entry.config),
                        context: context,
                        vaultExporter: vaultExporter,
                        localMerger: localMerger,
                        dateStore: dateStore
                    )
                case .s3(let entry):
                    Self.makeService(
                        id: entry.id,
                        kind: .s3,
                        session: BackupS3ServiceSession(config: entry.config),
                        context: context,
                        vaultExporter: vaultExporter,
                        localMerger: localMerger,
                        dateStore: dateStore
                    )
                case .iCloud(let entry):
                    CloudSyncAdapter(id: entry.id, cloudSync: cloudSync, dateStore: dateStore)
                }
            }
        }
    }

    private static func makeService(
        id: UUID,
        kind: SyncServiceKind,
        session: BackupFileServiceSession,
        context: BackupSyncContext,
        vaultExporter: BackupVaultExporting,
        localMerger: BackupLocalMerging,
        dateStore: BackupSyncDateStore
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
