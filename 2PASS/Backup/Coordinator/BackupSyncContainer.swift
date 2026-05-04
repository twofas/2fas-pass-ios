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
/// lock — while a sync is in flight, additional invocations short-circuit immediately by
/// throwing `.cancelled` instead of chaining behind the in-flight work. This stops e.g. a
/// periodic refresh from queueing up behind a user-initiated `Sync Now`. Cross-trigger
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

    /// Collaborators the container needs to run sessions: one to materialize the current set of
    /// services, one to look up per-config last-sync timestamps, one for the per-config
    /// "next sync needs special handling" awaiting flags. They start empty/no-op so that a
    /// freshly-`init()`-ed container is inert (zero services, no dates, no awaiting flags) and
    /// become real once `setup(...)` runs at app start. Stored together in a single lock so
    /// `setup`'s update is atomic — no torn read where one slot has been swapped but the others
    /// haven't yet.
    private struct Providers {
        var servicesProvider: @Sendable () -> [any BackupSynchronizing]
        var lastSyncDateProvider: @Sendable (UUID) -> Date?
        var awaitingFlags: BackupAwaitingFlagsStoring
        /// Cheap "what config ids exist right now" probe. Distinct from `servicesProvider`
        /// (which materializes full `BackupSynchronizing` sessions) so `markAllConfigsAwaitingVaultOverride`
        /// doesn't pay for session construction just to enumerate ids.
        var configIDsProvider: @Sendable () -> Set<UUID>

        static let empty = Providers(
            servicesProvider: { [] },
            lastSyncDateProvider: { _ in nil },
            awaitingFlags: EmptyAwaitingFlagsStore(),
            configIDsProvider: { [] }
        )
    }

    /// Inert default for the awaiting-flags slot before `setup(...)` runs. Reads as empty,
    /// marks no-op. Production wiring replaces it with the Data-layer adapter that persists
    /// to UserDefaults via `MainRepository`.
    private struct EmptyAwaitingFlagsStore: BackupAwaitingFlagsStoring {
        var vaultOverrideAwaitingConfigIDs: Set<UUID> { [] }
        func markVaultOverrideAwaiting(configIDs: Set<UUID>) {}
        var deviceRegistrationAwaitingConfigIDs: Set<UUID> { [] }
        func markDeviceRegistrationAwaiting(configIDs: Set<UUID>) {}
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
        cloudSync: CloudSync,
        awaitingFlags: BackupAwaitingFlagsStoring
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
            }
        )
        providers.withLock { $0 = newProviders }
    }

    /// Test-only initializer. Seeds the same lock-backed `Providers` storage `setup(...)`
    /// writes into — keeps existing tests that inject fake services/dates working without
    /// having to also stub `BackupSyncConfigStore` / `BackupVaultExporting` / etc. The
    /// awaiting-flags slot defaults to an empty store; tests that drive the per-config
    /// override / device-registration paths inject a fake conforming to
    /// `BackupAwaitingFlagsStoring`.
    init(
        servicesProvider: @escaping @Sendable () -> [any BackupSynchronizing],
        lastSyncDateProvider: @escaping @Sendable (UUID) -> Date? = { _ in nil },
        awaitingFlagsStore: BackupAwaitingFlagsStoring = EmptyAwaitingFlagsStore(),
        configIDsProvider: @escaping @Sendable () -> Set<UUID> = { [] }
    ) {
        providers.withLock { providers in
            providers.servicesProvider = servicesProvider
            providers.lastSyncDateProvider = lastSyncDateProvider
            providers.awaitingFlags = awaitingFlagsStore
            providers.configIDsProvider = configIDsProvider
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

    // MARK: - Awaiting flags (per-config "next sync needs special handling")
    //
    // Read + mark surface for the two persistent flag sets. Reads and marks both go through
    // the store snapshot under the providers lock so a concurrent `setup(...)` can't tear
    // them. Clearing happens elsewhere — `BackupSyncAdapter.setLastSyncDate(_:for:consumed:)`
    // observes session success and clears the matching id directly through `MainRepository`.

    /// Set of backup-config IDs that should overwrite their remote on the next sync. Populated
    /// per-config (not as a single global Bool) so that with multiple registered backends —
    /// e.g. two WebDAV servers, an S3 bucket, and iCloud — every one re-pushes the freshly
    /// re-encrypted vault after a master-password change, not just whichever one syncs first.
    /// Each entry is removed independently when its specific config syncs successfully (with
    /// `consumed.overwritingVault == true` on the `.finished` event).
    public var vaultOverrideAwaitingConfigIDs: Set<UUID> {
        providers.withLock { $0.awaitingFlags.vaultOverrideAwaitingConfigIDs }
    }

    /// Marks every currently-registered backend config for vault overwrite on its next sync.
    /// The container resolves the id set itself via its config store, so callers (the
    /// password-change flow) don't enumerate configs themselves and don't need a separate
    /// `BackupSyncConfigsInteracting` dependency just for this. No-op when no configs are
    /// registered. Safe to call regardless of backend kind: each `performSync` decides
    /// per-kind whether to honor the flag, and `BackupSyncAdapter.setLastSyncDate(_:for:consumed:)`
    /// only clears ids whose sync reported `consumed.overwritingVault == true`.
    public func markAllConfigsAwaitingVaultOverride() {
        let snapshot = providers.withLock { $0 }
        let configIDs = snapshot.configIDsProvider()
        guard !configIDs.isEmpty else { return }
        snapshot.awaitingFlags.markVaultOverrideAwaiting(configIDs: configIDs)
    }

    /// Set of backup-config IDs that need `allowingAnyDeviceId: true` on their next sync.
    /// Mirrors `vaultOverrideAwaitingConfigIDs` but addresses a different problem: after
    /// recovery, the local device hasn't yet written its `deviceID` into the remote index.
    /// Until that first sync succeeds, routine syncs would trip the multi-device-id gate.
    /// `syncAll()` and `sync(_:)` both read this set when building each session's per-id
    /// `allowingAnyDeviceId` resolver, so a failed first attempt auto-retries with the
    /// override on every subsequent sync until success.
    public var deviceRegistrationAwaitingConfigIDs: Set<UUID> {
        providers.withLock { $0.awaitingFlags.deviceRegistrationAwaitingConfigIDs }
    }

    /// Marks the supplied config id for `allowingAnyDeviceId: true` on its next sync. Used
    /// by the recovery flow on the specific config it just added — the flag drives every
    /// subsequent sync (immediate post-recovery push and any retry — routine, per-row, etc.)
    /// until the first successful sync clears it via
    /// `BackupSyncAdapter.setLastSyncDate(_:for:consumed:)`.
    public func markAwaitingDeviceRegistration(configID: UUID) {
        let store = providers.withLock { $0.awaitingFlags }
        store.markDeviceRegistrationAwaiting(configIDs: [configID])
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
    /// outcomes, or have caller-task cancellation propagate. Cross-client cancellation works
    /// for both forms via `cancelCurrentSync()`.
    public func syncAll() {
        Task.detached(priority: .utility) { [weak self] in
            try? await self?.syncAll()
        }
    }

    /// Awaitable overload. Returns each service's final `BackupSyncSession.SyncResult` from
    /// the convergence loop. Returns an empty array when no services are configured. Throws
    /// `.cancelled` when the call was suppressed because another sync was already in flight
    /// (debounced).
    ///
    /// Reads the awaiting-flag sets (`vaultOverrideAwaitingConfigIDs`,
    /// `deviceRegistrationAwaitingConfigIDs`) once at the top of the call and forwards
    /// per-service `overwritingVault` / `allowingAnyDeviceId` resolvers built from those
    /// snapshots, so callers don't manage the flags themselves — the container decides
    /// per-config whether the run overwrites/registers or merges.
    @discardableResult
    public func syncAll() async throws(BackupSyncError) -> [BackupSyncSession.SyncResult] {
        guard reserveSyncSlot() else {
            Log("BackupSyncContainer - syncAll ignored: sync already in progress", module: .backup)
            throw .cancelled
        }
        // Snapshot providers (and the awaiting flags off the same store) once per call so an
        // in-flight `setup(...)` can't tear the read, and so a clear-while-running sequence
        // (entries removed by the adapter as services finish) doesn't make a still-running
        // peer suddenly lose its flag mid-pass.
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

    /// Runs only the backend with the given id through a single-service `BackupSyncSession`.
    /// Returns silently when no service matches the id (defensive — caller should have just
    /// resolved this id from the configs) or when the run succeeds. Throws on actual failure
    /// or when debounced because another sync is in flight.
    ///
    /// Mirrors `syncAll()` for the per-service flag handling: reads both awaiting-flag sets
    /// from the store and forwards `overwritingVault` / `allowingAnyDeviceId` derived from
    /// whether `id` is present. Callers (recovery flow, per-row "Sync now" buttons) don't
    /// pass flag arguments — they mark via `markAllConfigsAwaitingVaultOverride()` /
    /// `markAwaitingDeviceRegistration(configID:)` and the container does the rest. A failed
    /// attempt's flags persist for any subsequent sync (routine, per-row, or `syncAll`)
    /// until the first success clears them per-id via `BackupSyncAdapter.setLastSyncDate`.
    public func sync(_ id: UUID) async throws(BackupSyncError) {
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
