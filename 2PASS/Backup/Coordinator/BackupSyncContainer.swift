// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os
import Common

/// Error type for `BackupSyncContainer.fetchIndex(config:)`. Splits transport failure (any
/// `BackupFileServiceError` from the underlying file service) from JSON-decode failure so
/// recovery UX can show distinct messages — "no index at this URL" vs. "the index file is
/// corrupted." The orchestrated sync path (`BackupFileSyncSession`) doesn't use this type:
/// its decode-failure policy is "treat as no-index, overwrite next sync," which differs.
public enum BackupIndexFetchError: Error, Sendable {
    case transport(BackupFileServiceError)
    case indexIsDamaged
}

/// Error type for `BackupSyncContainer.fetchVault(vaultID:config:)`. Three-way split:
/// transport failure (`BackupFileServiceError`), schema version above the build's known
/// range (extracted from `ExchangeDecodeError.schemaNotSupported`), or a generic decode
/// failure (corrupted vault file). Recovery UX maps each to a distinct user-facing state.
public enum BackupVaultFetchError: Error, Sendable {
    case transport(BackupFileServiceError)
    case schemaNotSupported(Int)
    case vaultIsDamaged
}

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
/// **API shape.** Both `syncAll(...)` and `sync(_:)` are `async` and return their results
/// when the underlying session completes. They share three cancellation paths, all of which
/// route to the same internal `Task.cancel()`:
///   1. The caller's parent task is cancelled — propagates via `withTaskCancellationHandler`.
///   2. Any code calls `cancelCurrentSync()` — fires the closure stashed by
///      `installCancellationHandler` for whatever sync is in flight.
///   3. The session itself short-circuits between services on `Task.isCancelled`.
/// Live activity is exposed via `syncEvents()` (multi-subscriber `AsyncStream`); there is
/// no per-call event handler argument.
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

    /// Two closures the container needs to run sessions: one to materialize the current set of
    /// services, one to look up per-config last-sync timestamps. They start empty so that a
    /// freshly-`init()`-ed container is inert (zero services, no dates) and become real once
    /// `setup(...)` runs at app start. Stored together in a single lock so `setup`'s update
    /// is atomic — no torn read where `servicesProvider` has been swapped but
    /// `lastSyncDateProvider` hasn't yet.
    private struct Providers {
        var servicesProvider: @Sendable () -> [any BackupSynchronizing]
        var lastSyncDateProvider: @Sendable (UUID) -> Date?

        static let empty = Providers(
            servicesProvider: { [] },
            lastSyncDateProvider: { _ in nil }
        )
    }

    private let providers = OSAllocatedUnfairLock<Providers>(initialState: .empty)
    private let state = OSAllocatedUnfairLock(initialState: State())
    /// Active `syncEvents()` subscribers. UUID-keyed so `onTermination` can remove a specific
    /// continuation without touching the others. Each session's events fan out to every
    /// entry here on every yield.
    private let syncEventContinuations = OSAllocatedUnfairLock<[UUID: AsyncStream<BackupSyncSession.Event>.Continuation]>(initialState: [:])

    /// Creates an inert container. Until `setup(...)` runs the container has zero services
    /// and `syncAll` / `sync(_:)` no-op gracefully — that's the point: callers (specifically
    /// `MainRepositoryImpl`) can store this as a non-optional `let` from their own init,
    /// then have an upper-layer interactor wire it up post-init via `setup(...)`.
    public init() {}

    /// Wires the container's collaborators after construction. Required before any sync
    /// produces useful work — calls before `setup` no-op gracefully (zero services →
    /// `syncAll` returns empty results, `currentActivity` reads `.idle`). Idempotent: a
    /// second call atomically replaces the providers, which is the supported way to swap
    /// collaborators (e.g. test re-wiring) since the container itself is single-instance
    /// for the app lifetime.
    public func setup(
        configStore: BackupSyncConfigStore,
        dateStore: BackupSyncDateStore,
        context: BackupSyncContext,
        vaultExporter: BackupVaultExporting,
        localMerger: BackupLocalMerging,
        cloudSync: CloudSync
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
            }
        )
        providers.withLock { $0 = newProviders }
    }

    /// Test-only initializer. Seeds the same lock-backed `Providers` storage `setup(...)`
    /// writes into — keeps existing tests that inject fake services/dates working without
    /// having to also stub `BackupSyncConfigStore` / `BackupVaultExporting` / etc.
    init(
        servicesProvider: @escaping @Sendable () -> [any BackupSynchronizing],
        lastSyncDateProvider: @escaping @Sendable (UUID) -> Date? = { _ in nil }
    ) {
        providers.withLock { providers in
            providers.servicesProvider = servicesProvider
            providers.lastSyncDateProvider = lastSyncDateProvider
        }
    }

    deinit {
        // Finish every outstanding `syncEvents()` subscriber so their for-await loops exit
        // cleanly. Without this, an abandoned subscriber whose Task isn't cancelled would
        // block forever waiting for the next yield.
        syncEventContinuations.withLock { dict in
            for continuation in dict.values {
                continuation.finish()
            }
            dict.removeAll()
        }
    }

    // MARK: - Ad-hoc transport reads (no session, no setup required)

    /// Fetches the remote index file for a file-based backend and decodes it as a
    /// `BackupIndex`. Independent of `setup(...)` — works against ad-hoc credentials (the
    /// recovery flow's case: user types URL / S3 credentials, we read the remote index,
    /// they pick a vault, then we register the config). Decode failures are surfaced
    /// distinctly from transport failures via `BackupIndexFetchError`, which lets callers
    /// map "no index yet" (`.transport(.notFound)`) and "damaged index" (`.indexIsDamaged`)
    /// to different UX states.
    ///
    /// Two overloads — one per file-based backend kind. iCloud is intentionally excluded:
    /// it has no file-based index (CloudKit records, separate state machine).
    ///
    /// The orchestrated sync path (`BackupFileSyncSession.fetchIndex()`) decodes the same
    /// type with **different policy**: it folds decode failure into "no index" (overwrite
    /// next sync). Recovery treats decode failure as a hard error, hence the dedicated
    /// `.indexIsDamaged` case here.

    public func fetchIndex(config: BackupWebDAVConfig) async throws(BackupIndexFetchError) -> BackupIndex {
        let session = BackupWebDAVServiceSession(config: config)
        return try await fetchAndDecodeIndex(session: session)
    }

    public func fetchIndex(config: S3ServiceConfig) async throws(BackupIndexFetchError) -> BackupIndex {
        let session = BackupS3ServiceSession(config: config)
        return try await fetchAndDecodeIndex(session: session)
    }

    /// Fetches the encrypted vault blob for `vaultID` from a file-based backend and decodes
    /// it as an `ExchangeVaultVersioned`. Same independence rationale as `fetchIndex(config:)`:
    /// recovery flows hit this *before* registering the config, so there's no orchestrated
    /// session to lean on. The custom `Decodable` impl on `ExchangeVaultVersioned` peeks
    /// `schemaVersion` and dispatches v1/v2 internally — anything outside that range surfaces
    /// distinctly via `BackupVaultFetchError.schemaNotSupported(_)` so recovery UX can route
    /// "you need a newer build" separately from "the file is corrupted."
    ///
    /// The orchestrated sync path (`BackupFileSyncSession.fetchRemoteVault`) does the same
    /// `JSONDecoder().decode(ExchangeVaultVersioned.self, ...)` but folds decode failure into
    /// `nil` (overwrite next sync). Recovery treats decode failure as a hard error, hence
    /// the dedicated `.vaultIsDamaged` case here.

    public func fetchVault(vaultID: UUID, config: BackupWebDAVConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        let session = BackupWebDAVServiceSession(config: config)
        return try await fetchAndDecodeVault(vaultID: vaultID, session: session)
    }

    public func fetchVault(vaultID: UUID, config: S3ServiceConfig) async throws(BackupVaultFetchError) -> ExchangeVaultVersioned {
        let session = BackupS3ServiceSession(config: config)
        return try await fetchAndDecodeVault(vaultID: vaultID, session: session)
    }

    /// Connection probe used by the config-creation UI to validate credentials before
    /// persisting a new backend. Builds a transient `BackupFileServiceSession` for the
    /// supplied config and runs `testConnection()` (auth + index-read in one call). Returns
    /// silently on success including the fresh-setup "no index yet" case — that 404 is
    /// folded into success inside the session implementations. Independent of `setup(...)`
    /// for the same reason as `fetchIndex(config:)`: the user hasn't registered the config
    /// yet, so there's nothing for an orchestrated session to attach to.

    public func testConnection(config: BackupWebDAVConfig) async throws(BackupFileServiceError) {
        let session = BackupWebDAVServiceSession(config: config)
        try await session.testConnection()
    }

    public func testConnection(config: S3ServiceConfig) async throws(BackupFileServiceError) {
        let session = BackupS3ServiceSession(config: config)
        try await session.testConnection()
    }

    // MARK: - Sync (each call builds a fresh BackupSyncSession)

    public var currentActivity: BackupSyncActivity {
        state.withLock { $0.activity }
    }

    public func cancelCurrentSync() {
        let cancel = state.withLock { $0.cancelCurrentSync }
        cancel?()
    }

    /// Stream of progress events from every session this container runs. Each call returns a
    /// fresh `AsyncStream` — multiple subscribers can listen concurrently, each at their own
    /// pace. Events fan out to every active subscriber the moment a session yields them; if a
    /// subscriber's task is cancelled (or its for-await loop exits) the continuation is
    /// automatically removed via `onTermination`.
    ///
    /// The fan-out runs alongside the container's internal bookkeeping handler, so
    /// `currentActivity` reads remain consistent with the events seen here.
    ///
    /// **Ordering caveat:** subscribers consume events asynchronously off the session's thread,
    /// so handlers that mutate persistent state in response to a `.finished` event no longer
    /// have a synchronous happens-before guarantee against work running concurrently on the
    /// caller's thread. For the in-tree usage (post-password-change override-flag clearing)
    /// this is benign — the race window is microsecond-scale and the worst case is one extra
    /// sync cycle.
    public func syncEvents() -> AsyncStream<BackupSyncSession.Event> {
        let subscriberID = UUID()
        return AsyncStream(bufferingPolicy: .unbounded) { [weak self] continuation in
            self?.syncEventContinuations.withLock { $0[subscriberID] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.syncEventContinuations.withLock { $0.removeValue(forKey: subscriberID) }
            }
        }
    }

    /// Fire-and-forget overload. Triggers a sync at background (`.utility`) priority and
    /// returns immediately — use this from any non-async site that just wants "propagate to
    /// backups when convenient" without managing a `Task` itself. Spawns a detached task
    /// internally: no caller actor isolation, no priority inheritance, no task-local
    /// inheritance — sync work stays explicitly off the caller's executor.
    ///
    /// Use the `async` overload below when you need to track completion, read per-service
    /// results, or have caller-task cancellation propagate. Cross-client cancellation works
    /// for both forms via `cancelCurrentSync()`.
    public func syncAll(
        overwritingVault: @Sendable @escaping (UUID) -> Bool = { _ in false },
        allowingAnyDeviceId: @Sendable @escaping (UUID) -> Bool = { _ in false }
    ) {
        Task.detached(priority: .utility) { [weak self] in
            await self?.syncAll(
                overwritingVault: overwritingVault,
                allowingAnyDeviceId: allowingAnyDeviceId
            )
        }
    }

    @discardableResult
    public func syncAll(
        overwritingVault: @Sendable @escaping (UUID) -> Bool = { _ in false },
        allowingAnyDeviceId: @Sendable @escaping (UUID) -> Bool = { _ in false }
    ) async -> [BackupSyncSession.SyncResult] {
        guard reserveSyncSlot() else {
            Log("BackupSyncContainer - syncAll ignored: sync already in progress", module: .backup)
            return []
        }
        // Snapshot providers once per call so an in-flight `setup(...)` can't tear the read.
        let snapshot = providers.withLock { $0 }
        let session = BackupSyncSession(
            services: snapshot.servicesProvider(),
            overwritingVault: overwritingVault,
            allowingAnyDeviceId: allowingAnyDeviceId,
            lastSyncDate: snapshot.lastSyncDateProvider,
            onEvent: makeSyncEventHandler()
        )
        let task = Task { [self] in
            defer { self.clearSyncSlot() }
            let results = await session.run()
            self.postAppliedRemoteChangesIfNeeded(results)
            return results
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

    @discardableResult
    public func sync(
        _ id: UUID,
        overwritingVault: Bool = false,
        allowingAnyDeviceId: Bool = false
    ) async -> Result<BackupSyncOutcome, BackupSyncError>? {
        let snapshot = providers.withLock { $0 }
        guard let service = snapshot.servicesProvider().first(where: { $0.id == id }) else { return nil }
        guard reserveSyncSlot() else {
            Log("BackupSyncContainer - sync ignored: sync already in progress", module: .backup)
            return .failure(.cancelled)
        }
        let session = BackupSyncSession(
            services: [service],
            // Single-service path: the per-service closure trivially returns the caller's
            // Bool for this id. Keeps `sync(_:)`'s public signature ergonomic for callers
            // (recovery flow, per-row "Sync now" buttons) that don't deal in id sets.
            overwritingVault: { _ in overwritingVault },
            allowingAnyDeviceId: { _ in allowingAnyDeviceId },
            lastSyncDate: snapshot.lastSyncDateProvider,
            onEvent: makeSyncEventHandler()
        )
        let task = Task { [self] in
            let results = await session.run()
            self.postAppliedRemoteChangesIfNeeded(results)
            return results.first?.outcome
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

    /// Fan-out helper for events the *container* (not the session) emits — currently
    /// `.sessionStarted` / `.sessionFinished`. Also reused by the session-event path through
    /// `makeSyncEventHandler`. `yield` is non-blocking — each subscriber's continuation has its
    /// own buffer (default unbounded) so a slow consumer doesn't back-pressure emitters.
    private func broadcast(_ event: BackupSyncSession.Event) {
        syncEventContinuations.withLock { dict in
            for continuation in dict.values {
                continuation.yield(event)
            }
        }
    }

    private func postAppliedRemoteChangesIfNeeded(_ results: [BackupSyncSession.SyncResult]) {
        let applied = results.contains { result in
            if case .success(let outcome) = result.outcome { return outcome.appliedRemoteChanges }
            return false
        }
        guard applied else { return }
        NotificationCenter.default.post(name: .backupSyncDidApplyRemoteChanges, object: nil)
    }

    private func handle(_ event: BackupSyncSession.Event) {
        state.withLock { state in
            switch event {
            case .started(let id, _):
                state.activeConfigIDs.insert(id)
            case .finished(let id, _, _):
                state.activeConfigIDs.remove(id)
            case .sessionStarted, .sessionFinished:
                // Container emits these directly via `broadcast(_:)` — they never flow through
                // this session-handler path. Listed for exhaustiveness only.
                break
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
