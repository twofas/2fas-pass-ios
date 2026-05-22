// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Common

/// Error for ad-hoc `fetchIndex` reads: transport failure vs. corrupted index file.
/// The orchestrated sync path folds decode failure into "no index, overwrite next sync"
/// instead, so it doesn't use this type.
public enum BackupIndexFetchError: Error, Sendable {
    case transport(BackupFileServiceError)
    case indexIsDamaged
}

/// Error for ad-hoc `fetchVault` reads: transport, unsupported schema version, or generic
/// decode failure.
public enum BackupVaultFetchError: Error, Sendable {
    case transport(BackupFileServiceError)
    case schemaNotSupported(Int)
    case vaultIsDamaged
}

/// Posted by `saveConfigs(_:)` after each successful persistence. Payload-less — consumers
/// re-read `MainRepository.loadBackupConfigs()` in response.
public struct BackupConfigsDidChange: Notifications.AsyncMessage {
    public typealias Subject = NSObject
    public init() {}
}

/// Runs registered backup-sync backends through the convergence loop.
///
/// Inert until `setup(...)` runs. Each `syncAll` / `sync(_:)` call freshly loads configs,
/// rebuilds services, and constructs a fresh `BackupSyncSession`. Overlapping triggers are
/// debounced via an unfair lock: while a sync is in flight, additional invocations throw
/// `.cancelled` instead of queueing.
public final class BackupSyncContainer: @unchecked Sendable {
    private struct State {
        var isSyncing = false
        var activeConfigIDs: Set<BackupConfig.ID> = []
        var cancelCurrentSync: (@Sendable () -> Void)?

        var activity: BackupSyncActivity {
            BackupSyncActivity(isRunning: isSyncing, activeConfigIDs: activeConfigIDs)
        }
    }

    /// Slots wired up by `setup(...)`. Empty/no-op defaults keep a freshly-init'd container
    /// inert. Stored together under one lock so `setup`'s update is atomic.
    private struct Providers {
        var servicesProvider: @Sendable () -> [any BackupSynchronizing]
        var lastSyncDateProvider: @Sendable (BackupConfig.ID) -> Date?
        var awaitingFlags: BackupAwaitingFlagsStoring
        var configIDsProvider: @Sendable () -> Set<BackupConfig.ID>
        var configStore: BackupSyncConfigStore?

        static let empty = Providers(
            servicesProvider: { [] },
            lastSyncDateProvider: { _ in nil },
            awaitingFlags: EmptyAwaitingFlagsStore(),
            configIDsProvider: { [] },
            configStore: nil
        )
    }

    private struct EmptyAwaitingFlagsStore: BackupAwaitingFlagsStoring {
        var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> { [] }
        func markVaultOverrideAwaiting(configIDs: Set<BackupConfig.ID>) {}
        var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> { [] }
        func markDeviceRegistrationAwaiting(configIDs: Set<BackupConfig.ID>) {}
    }

    private let providers = OSAllocatedUnfairLock<Providers>(initialState: .empty)
    private let state = OSAllocatedUnfairLock(initialState: State())
    private let syncEventContinuations = OSAllocatedUnfairLock<[UUID: AsyncStream<BackupSyncSession.Event>.Continuation]>(initialState: [:])
    /// Process-scoped last-error per config. Cleared on next success or on config removal.
    /// `.cancelled` outcomes are skipped (user-initiated cancel isn't an error).
    private let lastErrors = OSAllocatedUnfairLock<[BackupConfig.ID: BackupSyncError]>(initialState: [:])

    /// Token for the in-module finished-sync handler that synthesizes a `.finished(.success)`
    /// event when a `cloudSync` completion arrives from a push (i.e. outside any active
    /// session). Self-suppresses while a session is in flight to avoid double-firing.
    private let cloudSyncPushBridgeToken = OSAllocatedUnfairLock<UUID?>(initialState: nil)

    private let cloudSync = CloudSync()
    private let cloudRecovery: CloudRecovering = CloudRecovery()

    public init() {}

    /// Wires collaborators and applies the per-vault CloudSync configuration. Idempotent —
    /// re-call to re-apply (used by vault recovery once the recovered vault is selected).
    /// Bails on `nil` `context.deviceID`; caller re-runs once deviceID is available.
    public func setup(
        configStore: BackupSyncConfigStore,
        dateStore: BackupSyncDateStore,
        context: BackupSyncContext,
        vaultExporter: BackupVaultExporting,
        localMerger: BackupLocalMerging,
        awaitingFlags: BackupAwaitingFlagsStoring,
        localStorage: LocalStorage,
        cloudCacheStorage: CloudCacheStorage,
        encryptionHandler: EncryptionHandler,
        currentDate: Date
    ) {
        let newProviders = Providers(
            servicesProvider: Self.makeServicesProvider(
                configStore: configStore,
                dateStore: dateStore,
                context: context,
                vaultExporter: vaultExporter,
                localMerger: localMerger,
                cloudSync: cloudSync
            ),
            lastSyncDateProvider: { [dateStore] id in
                dateStore.lastSyncDate(for: id)
            },
            awaitingFlags: awaitingFlags,
            configIDsProvider: { [configStore] in
                Set(configStore.loadConfigs().map(\.id))
            },
            configStore: configStore
        )
        providers.withLock { $0 = newProviders }

        cloudSync.setCurrentDate(currentDate)

        cloudSync.setup(
            localStorage: localStorage,
            cloudCacheStorage: cloudCacheStorage,
            encryptionHandler: encryptionHandler,
            jsonDecoder: JSONDecoder(),
            jsonEncoder: JSONEncoder(),
            context: context
        )
        installCloudSyncPushBridgeIfNeeded()
        cloudSync.checkState()
    }

    private func installCloudSyncPushBridgeIfNeeded() {
        let alreadyInstalled = cloudSyncPushBridgeToken.withLock { $0 != nil }
        guard !alreadyInstalled else { return }
        let token = cloudSync.addFinishedSyncHandler { [weak self] applied in
            self?.handleICloudFinishedOutsideSession(applied: applied)
        }
        cloudSyncPushBridgeToken.withLock { $0 = token }
    }

    private func handleICloudFinishedOutsideSession(applied: Bool) {
        let inSession = state.withLock { $0.isSyncing }
        guard !inSession else { return }
        let snapshot = providers.withLock { $0 }
        guard let iCloudService = snapshot.servicesProvider().first(where: { $0.kind == .iCloud }) else { return }
        let outcome = BackupSyncOutcome(appliedRemoteChanges: applied)
        let event = BackupSyncSession.Event.finished(
            id: iCloudService.id,
            kind: .iCloud,
            outcome: .success(outcome)
        )
        // Same handle → broadcast order as the session path so `lastErrors[id]` is cleared
        // alongside the fan-out.
        handle(event)
        broadcast(event)
    }

    /// Test-only init. Awaiting-flags slot defaults to an empty store; tests driving the
    /// override / device-registration paths inject a conforming fake.
    init(
        servicesProvider: @escaping @Sendable () -> [any BackupSynchronizing],
        lastSyncDateProvider: @escaping @Sendable (BackupConfig.ID) -> Date? = { _ in nil },
        awaitingFlagsStore: BackupAwaitingFlagsStoring = EmptyAwaitingFlagsStore(),
        configIDsProvider: @escaping @Sendable () -> Set<BackupConfig.ID> = { [] }
    ) {
        providers.withLock { providers in
            providers.servicesProvider = servicesProvider
            providers.lastSyncDateProvider = lastSyncDateProvider
            providers.awaitingFlags = awaitingFlagsStore
            providers.configIDsProvider = configIDsProvider
        }
    }

    deinit {
        syncEventContinuations.withLock { dict in
            for continuation in dict.values {
                continuation.finish()
            }
            dict.removeAll()
        }
    }

    // MARK: - Config CRUD

    /// Single seam where the iCloud lifecycle is reconciled with the presence of a
    /// `BackupConfig.iCloud(...)` entry. Order matters: reads `old` before writing `new` —
    /// flipping the order would silently observe `old == new`.
    public func saveConfigs(_ configs: [BackupConfig]) {
        let store = providers.withLock { $0.configStore }
        guard let store else { return }
        let old = store.loadConfigs()
        store.saveConfigs(configs)
        reconcileICloudLifecycle(old: old, new: configs)
        reconcileLastErrors(old: old, new: configs)
        NotificationCenter.default.post(BackupConfigsDidChange())
    }

    private func reconcileICloudLifecycle(old: [BackupConfig], new: [BackupConfig]) {
        let oldHasICloud = old.contains { if case .iCloud = $0 { true } else { false } }
        let newHasICloud = new.contains { if case .iCloud = $0 { true } else { false } }
        if !oldHasICloud && newHasICloud {
            cloudSync.enable()
        } else if oldHasICloud && !newHasICloud {
            cloudSync.disable(notify: true)
        }
    }

    /// Drops `lastErrors[id]` for removed configs so `hasAnySyncError` can't stay stuck
    /// on `true` for an id that no longer exists.
    private func reconcileLastErrors(old: [BackupConfig], new: [BackupConfig]) {
        let newIDs = Set(new.map(\.id))
        let removed = old.compactMap { newIDs.contains($0.id) ? nil : $0.id }
        guard !removed.isEmpty else { return }
        lastErrors.withLock { dict in
            for id in removed { dict[id] = nil }
        }
    }

    public var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> {
        NotificationCenter.default.messages(of: BackupConfigsDidChange.self)
    }

    // MARK: - Ad-hoc transport reads (no session, no setup required)

    /// Fetches and decodes the remote index. Independent of `setup(...)` — used by the
    /// recovery flow before any config has been registered. Decode failure is surfaced
    /// distinctly from transport failure via `BackupIndexFetchError`.

    public func fetchIndex(config: BackupWebDAVConfig) async throws(BackupIndexFetchError) -> BackupIndex {
        let session = BackupWebDAVServiceSession(config: config)
        return try await fetchAndDecodeIndex(session: session)
    }

    public func fetchIndex(config: S3ServiceConfig) async throws(BackupIndexFetchError) -> BackupIndex {
        let session = BackupS3ServiceSession(config: config)
        return try await fetchAndDecodeIndex(session: session)
    }

    /// Fetches and decodes the vault blob for `vaultID`. Same independence-from-`setup`
    /// rationale as `fetchIndex(config:)`; schema-version mismatches are surfaced as
    /// `.schemaNotSupported`.

    public func fetchVault(vaultID: UUID, config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        let session = BackupWebDAVServiceSession(config: config)
        return try await fetchAndDecodeVault(vaultID: vaultID, session: session)
    }

    public func fetchVault(vaultID: UUID, config: S3ServiceConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        let session = BackupS3ServiceSession(config: config)
        return try await fetchAndDecodeVault(vaultID: vaultID, session: session)
    }

    /// Auth + index-read probe used to validate credentials before persisting a new config.
    /// Returns silently on success, including the "no index yet" 404 (folded into success).

    public func testConnection(config: BackupWebDAVConfig) async throws(BackupFileServiceError) {
        let session = BackupWebDAVServiceSession(config: config)
        try await session.testConnection()
    }

    public func testConnection(config: S3ServiceConfig) async throws(BackupFileServiceError) {
        let session = BackupS3ServiceSession(config: config)
        try await session.testConnection()
    }

    // MARK: - iCloud recovery (no Config; identity-based)

    public func listICloudVaultsToRecover() async throws -> [VaultRawData] {
        try await cloudRecovery.listVaultsToRecover()
    }

    public func deleteICloudVault(id: VaultID) async throws {
        try await cloudRecovery.deleteVault(id: id)
    }

    // MARK: - Awaiting flags (per-config "next sync needs special handling")

    /// Marks every registered config for vault overwrite on its next sync. Used by the
    /// password-change flow. Each backend's `performSync` decides per-kind whether to honor
    /// the flag; `BackupSyncAdapter.setLastSyncDate(_:for:consumed:)` clears per-id only
    /// when the sync reported `consumed.overwritingVault`.
    public func markAllConfigsAwaitingVaultOverride() {
        let snapshot = providers.withLock { $0 }
        let configIDs = snapshot.configIDsProvider()
        guard !configIDs.isEmpty else { return }
        snapshot.awaitingFlags.markVaultOverrideAwaiting(configIDs: configIDs)
    }

    /// Marks `configID` for `allowingAnyDeviceId: true` on its next sync. Persists across
    /// retries; cleared by the first successful sync via `setLastSyncDate`.
    public func markAwaitingDeviceRegistration(configID: BackupConfig.ID) {
        let store = providers.withLock { $0.awaitingFlags }
        store.markDeviceRegistrationAwaiting(configIDs: [configID])
    }

    // MARK: - Sync (each call builds a fresh BackupSyncSession)

    public var currentActivity: BackupSyncActivity {
        state.withLock { $0.activity }
    }

    /// Most recent failure for `id` in this app process, or `nil` if the last sync succeeded
    /// or no sync has run. Process-scoped — not persisted. `.cancelled` outcomes never appear.
    public func lastSyncError(for id: BackupConfig.ID) -> BackupSyncError? {
        lastErrors.withLock { $0[id] }
    }

    /// Single-bit rollup over `lastSyncError(for:)` — drives the global "any backup is
    /// broken" badge.
    public var hasAnySyncError: Bool {
        lastErrors.withLock { !$0.isEmpty }
    }

    public func cancelCurrentSync() {
        let cancel = state.withLock { $0.cancelCurrentSync }
        cancel?()
    }

    /// CloudKit silent-push entry point. Bypasses the container's in-flight debounce: the
    /// `fromPush: true` flag is load-bearing inside `SyncHandler.synchronize` — it triggers
    /// `needsResync` when a sync is already past its fetch phase, so the push isn't dropped.
    public func handlePush() {
        cloudSync.synchronize(fromPush: true)
    }

    /// Per-id cancel. No-op when `id` isn't currently active — a tap on one row mustn't
    /// tear down a sync running for a different config.
    public func cancelSync(id: BackupConfig.ID) {
        let cancel = state.withLock { state in
            state.activeConfigIDs.contains(id) ? state.cancelCurrentSync : nil
        }
        cancel?()
    }

    /// Multi-subscriber event stream. Each call returns a fresh `AsyncStream`; continuations
    /// are auto-removed via `onTermination`. Fan-out is non-blocking (per-subscriber buffer).
    public func syncEvents() -> AsyncStream<BackupSyncSession.Event> {
        let subscriberID = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { [weak self] continuation in
            self?.syncEventContinuations.withLock { $0[subscriberID] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.syncEventContinuations.withLock { $0.removeValue(forKey: subscriberID) }
            }
        }
    }

    /// Fire-and-forget: detached `.utility`-priority task. Cross-client cancellation via
    /// `cancelCurrentSync()`.
    public func syncAll() {
        Task.detached(priority: .utility) { [weak self] in
            try? await self?.syncAll()
        }
    }

    /// Awaitable. Returns each service's final result; empty when no services. Throws
    /// `.cancelled` when debounced. Reads the awaiting-flag sets once at the top and
    /// forwards them as per-id resolvers so the run is consistent across services.
    @discardableResult
    public func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult] {
        guard reserveSyncSlot() else {
            Log("BackupSyncContainer - syncAll ignored: sync already in progress", module: .backup)
            throw .cancelled
        }
        let snapshot = providers.withLock { $0 }
        let overrideAwaiting = snapshot.awaitingFlags.vaultOverrideAwaitingConfigIDs
        let registrationAwaiting = snapshot.awaitingFlags.deviceRegistrationAwaitingConfigIDs
        let session = BackupSyncSession(
            services: snapshot.servicesProvider(),
            overwritingVault: { configID in overrideAwaiting.contains(configID) },
            allowingAnyDeviceId: { configID in registrationAwaiting.contains(configID) },
            lastSyncDate: snapshot.lastSyncDateProvider,
            onEvent: makeSyncEventHandler()
        )
        let task = Task { [self] in
            defer { self.clearSyncSlot() }
            return await session.run()
        }
        installCancellationHandler {
            task.cancel()
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Fire-and-forget single-config sync. Cross-client cancellation via `cancelSync(id:)` /
    /// `cancelCurrentSync()`.
    public func sync(_ id: BackupConfig.ID) {
        Task.detached(priority: .utility) { [weak self] in
            try? await self?.sync(id)
        }
    }

    /// Runs only the backend with `id`. Silent no-op when nothing matches; throws on
    /// failure or `.cancelled` when debounced.
    public func sync(_ id: BackupConfig.ID) async throws(BackupSyncError) {
        let snapshot = providers.withLock { $0 }
        guard let service = snapshot.servicesProvider().first(where: { $0.id == id }) else { return }
        guard reserveSyncSlot() else {
            Log("BackupSyncContainer - sync ignored: sync already in progress", module: .backup)
            throw .cancelled
        }
        let needsOverride = snapshot.awaitingFlags.vaultOverrideAwaitingConfigIDs.contains(id)
        let needsRegistration = snapshot.awaitingFlags.deviceRegistrationAwaitingConfigIDs.contains(id)
        let session = BackupSyncSession(
            services: [service],
            overwritingVault: { _ in needsOverride },
            allowingAnyDeviceId: { _ in needsRegistration },
            lastSyncDate: snapshot.lastSyncDateProvider,
            onEvent: makeSyncEventHandler()
        )
        let task = Task {
            let results = await session.run()
            return results.first?.outcome
        }
        installCancellationHandler {
            task.cancel()
        }
        defer { clearSyncSlot() }
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        if case .failure(let error) = outcome { throw error }
    }

    // MARK: - Internals

    private func reserveSyncSlot() -> Bool {
        let reserved = state.withLock { state in
            guard !state.isSyncing else { return false }
            state.isSyncing = true
            return true
        }
        if reserved {
            broadcast(.sessionStarted)
        }
        return reserved
    }

    private func installCancellationHandler(
        _ cancelCurrentSync: @escaping @Sendable () -> Void
    ) {
        state.withLock { $0.cancelCurrentSync = cancelCurrentSync }
    }

    private func clearSyncSlot() {
        let cleared = state.withLock { state in
            guard state.isSyncing else { return false }
            state.isSyncing = false
            state.activeConfigIDs.removeAll()
            state.cancelCurrentSync = nil
            return true
        }
        if cleared {
            broadcast(.sessionFinished)
        }
    }

    private func makeSyncEventHandler() -> BackupSyncSession.EventHandler {
        { [weak self] event in
            self?.handle(event)
            self?.broadcast(event)
        }
    }

    private func broadcast(_ event: BackupSyncSession.Event) {
        syncEventContinuations.withLock { dict in
            for continuation in dict.values {
                continuation.yield(event)
            }
        }
    }

    private func handle(_ event: BackupSyncSession.Event) {
        state.withLock { state in
            switch event {
            case .started(let id, _):
                state.activeConfigIDs.insert(id)
            case .finished(let id, _, _):
                state.activeConfigIDs.remove(id)
            case .sessionStarted, .sessionFinished:
                break
            }
        }
        if case .finished(let id, _, let outcome) = event {
            switch outcome {
            case .success:
                lastErrors.withLock { $0[id] = nil }
            case .failure(.cancelled):
                // User-initiated cancel: leave any prior recorded error in place — the
                // underlying problem (network down, bad credentials, …) is unchanged.
                break
            case .failure(let error):
                lastErrors.withLock { $0[id] = error }
            }
        }
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
        id: BackupConfig.ID,
        kind: BackupSyncService,
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

    private func fetchAndDecodeIndex(session: some BackupFileServiceSession) async throws(BackupIndexFetchError) -> BackupIndex {
        let data: Data
        do {
            data = try await session.fetchIndex()
        } catch {
            throw .transport(error)
        }
        guard let index = try? JSONDecoder().decode(BackupIndex.self, from: data) else {
            throw .indexIsDamaged
        }
        return index
    }

    private func fetchAndDecodeVault(vaultID: UUID, session: some BackupFileServiceSession) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        let data: Data
        do {
            data = try await session.fetchVault(vaultID: vaultID)
        } catch {
            throw .transport(error)
        }
        do {
            return try JSONDecoder().decode(ExchangeVaultVersioned.self, from: data)
        } catch ExchangeDecodeError.schemaNotSupported(let version) {
            throw .schemaNotSupported(version)
        } catch {
            throw .vaultIsDamaged
        }
    }
}
