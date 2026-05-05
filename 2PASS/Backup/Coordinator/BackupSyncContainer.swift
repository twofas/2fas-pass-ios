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

/// Posted by `BackupSyncContainer.saveConfigs(_:)` exactly once after each successful
/// persistence of the config list. Payload-less by design: consumers re-read
/// `MainRepository.loadBackupConfigs()` (or whichever derived value they care about) in
/// response. Subject is unused — config state is global, not scoped to a particular
/// instance, so posters and observers both pass `subject: nil` (the default).
///
/// **Single-writer guarantee.** The container is the only writer of persisted configs in
/// the codebase: `BackupSyncConfigsInteractor`'s mutating methods all route through
/// `saveConfigs(_:)` here, and this message is posted once per successful call (gated on
/// the container being initialized — uninitialized saves no-op without firing the message,
/// since no actual persistence happened).
///
/// Built on the project's `Notifications.AsyncMessage` backport (in
/// `Common/Extensions/Notifications+TypedMessage.swift`), which mirrors iOS 26's
/// `NotificationCenter.AsyncMessage`. Migration when the deployment-target floor rises:
/// delete the backport and rename `Notifications.AsyncMessage` → `NotificationCenter.AsyncMessage`.
public struct BackupConfigsDidChange: Notifications.AsyncMessage {
    public typealias Subject = NSObject
    public init() {}
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
    /// "next sync needs special handling" awaiting flags, and a direct reference to the config
    /// store so the public `saveConfigs(_:)` entry point can route external CRUD through one
    /// place (the only place where iCloud lifecycle is reconciled with config presence). They
    /// start empty/no-op so that a freshly-`init()`-ed container is inert (zero services, no
    /// dates, no awaiting flags, no store) and become real once `setup(...)` runs at app start.
    /// Stored together in a single lock so `setup`'s update is atomic — no torn read where one
    /// slot has been swapped but the others haven't yet.
    private struct Providers {
        var servicesProvider: @Sendable () -> [any BackupSynchronizing]
        var lastSyncDateProvider: @Sendable (UUID) -> Date?
        var awaitingFlags: BackupAwaitingFlagsStoring
        /// Cheap "what config ids exist right now" probe. Distinct from `servicesProvider`
        /// (which materializes full `BackupSynchronizing` sessions) so `markAllConfigsAwaitingVaultOverride`
        /// doesn't pay for session construction just to enumerate ids.
        var configIDsProvider: @Sendable () -> Set<UUID>
        /// Direct reference to the config store. Used by `saveConfigs(_:)` to read the
        /// pre-write snapshot, persist the new list, and reconcile iCloud lifecycle with the
        /// before/after diff. `nil` until `setup(...)` runs — `saveConfigs(_:)` no-ops in that
        /// state, matching the rest of the inert-container behavior.
        var configStore: BackupSyncConfigStore?

        static let empty = Providers(
            servicesProvider: { [] },
            lastSyncDateProvider: { _ in nil },
            awaitingFlags: EmptyAwaitingFlagsStore(),
            configIDsProvider: { [] },
            configStore: nil
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
    /// Most recent failure per config id, observed off the session's `.finished` events. In-memory
    /// only — does not survive an app restart. Cleared per-id on the next successful `.finished`
    /// for that id; `.cancelled` outcomes are skipped (user-initiated cancel is not an error).
    /// Distinct lock from `state` because the two have no shared invariants and writes happen on
    /// the same event-handler thread, so two short critical sections beat one wider one.
    ///
    /// Stores `BackupSyncError` directly. UI consumers render the user-facing message via the
    /// type's `LocalizedError.errorDescription`, which resolves through the Backup module's own
    /// `Localizable.xcstrings`. Holding the structured error (rather than a kind+detail mirror)
    /// is fine because the container has process-scope lifetime — there's no persistence path
    /// that needs `Codable`, and the underlying `Error & Sendable` payload on `.network` /
    /// `.server` is freed on the next success or app close.
    private let lastErrors = OSAllocatedUnfairLock<[UUID: BackupSyncError]>(initialState: [:])

    /// The container's owned `CloudSync` engine. Constructed eagerly in init so that
    /// `MainRepositoryImpl` doesn't have to know it exists — there is exactly one CloudKit
    /// container per build, mirrored by exactly one `CloudSync` here. Configured per-vault by
    /// `setup(...)` (see the static deps + per-vault context parameters); driven by
    /// `CloudSyncAdapter` materialized for any persisted `BackupConfig.iCloud(...)` entry; and
    /// enabled/disabled as a side effect of `saveConfigs(_:)` detecting the iCloud entry being
    /// added or removed. There is no public accessor — every caller goes through one of the
    /// three integration points above.
    private let cloudSync = CloudSync()

    /// Creates an inert container. Until `setup(...)` runs the container has zero services
    /// and `syncAll` / `sync(_:)` no-op gracefully — that's the point: callers (specifically
    /// `MainRepositoryImpl`) can store this as a non-optional `let` from their own init,
    /// then have an upper-layer interactor wire it up post-init via `setup(...)`.
    public init() {}

    /// Wires the container's collaborators after construction and applies the per-vault
    /// `CloudSync` configuration. Required before any sync produces useful work — calls before
    /// `setup` no-op gracefully (zero services → `syncAll` returns empty results,
    /// `currentActivity` reads `.idle`, `saveConfigs(_:)` no-ops). Idempotent: a second call
    /// atomically replaces the providers and re-applies the CloudSync chain. This is the
    /// supported re-apply path used by vault recovery, which calls `setup(...)` again with the
    /// new selected `vaultID` once the recovered vault is the selected one. The "this vault's
    /// data is authoritative" signal during recovery is conveyed via
    /// `markAllConfigsAwaitingVaultOverride()` — a unified per-config flag the next sync
    /// honors via `CloudSyncAdapter.performSync(overwritingVault:)` — so `setup(...)` itself
    /// stays free of recovery-specific arguments.
    ///
    /// **CloudSync chain.** After writing the new providers, `setup(...)` runs:
    /// `setCurrentDate → setup → setMultiDeviceSyncEnabled → checkState`. The underlying
    /// `CloudSync.setup(...)` is itself idempotent (guards on internal `cloudHandler == nil`);
    /// the rest of the chain re-applies fresh values on every call. Vault id is **not**
    /// pushed here — `CloudHandler.sync()` reads `context.vaultID` lazily at sync time, so
    /// vault changes propagate without any re-init. Bails only on `nil` `context.deviceID`
    /// (still required at construction time for `MergeHandler`); the caller
    /// (`BackupSyncSetupInteractor`) is responsible for re-running once deviceID becomes
    /// available. Reading deviceID / vaultID / multi-device-sync from the `context`
    /// collaborator (rather than separate parameters) keeps the source of truth single —
    /// `BackupSyncAdapter` forwards each to `MainRepository`, so callers don't need to plumb
    /// three runtime values that the adapter already exposes.
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
        // Vault id is no longer pushed via `setVaultID(_:)` — `CloudHandler.sync()` reads
        // `context.vaultID` lazily on each sync, so vault changes propagate without a
        // re-init. The previous `guard let vaultID = context.vaultID` bail is gone too;
        // setup proceeds even when no vault is selected at launch.
        cloudSync.setMultiDeviceSyncEnabled(context.allowsMultiDeviceSync)
        cloudSync.checkState()
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

    // MARK: - Config CRUD

    /// External entry point for persisting the full `[BackupConfig]` list. The single
    /// integration seam where the iCloud lifecycle (`cloudSync.enable()` / `disable(notify:)`)
    /// is reconciled with the presence of a `BackupConfig.iCloud(...)` entry in the store.
    /// All callers (`BackupSyncConfigsInteractor.add*Config` / `update*Config` / `removeConfig`)
    /// route their saves here instead of writing the persistent store directly, so the diff
    /// is observed in exactly one place.
    ///
    /// **Order matters.** Reads `old` *before* writing `new` — `loadConfigs()` and the upcoming
    /// `saveConfigs(_:)` go through the same persistent store, so flipping the order would
    /// silently observe `old == new` after the write and the diff would never fire. Saves to
    /// file-based configs (WebDAV / S3) are no-ops here: the diff only checks the iCloud
    /// presence bit, and the next `syncAll` / `sync(_:)` rebuilds services from the new shape.
    ///
    /// No-ops gracefully when called before `setup(...)` runs (no `configStore` yet).
    public func saveConfigs(_ configs: [BackupConfig]) {
        let store = providers.withLock { $0.configStore }
        guard let store else { return }
        let old = store.loadConfigs()
        store.saveConfigs(configs)
        reconcileICloudLifecycle(old: old, new: configs)
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

    /// Most recent failure recorded for `id` during the running app process, or `nil` if the
    /// last sync for that id succeeded (or no sync has run for it yet). The container observes
    /// `.finished` events and records on `.failure` / clears on `.success` synchronously inside
    /// its session-event handler — by the time `currentActivity` reports the run as no longer
    /// active for `id`, this accessor reflects the just-completed outcome.
    ///
    /// **Process-scoped.** Not persisted. A force-quit-and-relaunch starts every config back at
    /// `nil` here. That's deliberate: the next sync trigger either replaces or clears the entry
    /// within minutes, so cross-launch persistence isn't worth the complexity.
    ///
    /// `.cancelled` outcomes never appear here — they're skipped at recording time, leaving any
    /// prior error in place (see `handle(_:)`).
    public func lastSyncError(for id: UUID) -> BackupSyncError? {
        lastErrors.withLock { $0[id] }
    }

    /// `true` when at least one backup config has a recorded last-sync error in the running app
    /// process. Drives the global "any backup is broken" badge on the tab bar and the Cloud
    /// Sync row in Settings — both consumers want a single bit, not a per-config breakdown,
    /// so the rollup belongs here rather than reconstructed from N `lastSyncError(for:)` reads.
    ///
    /// Same in-memory lock as `lastSyncError(for:)`, so a write that was just observed by
    /// `handle(_:)` is visible to this accessor on the next read — no separate consistency
    /// model. Returns `false` when the dictionary is empty (no errors ever recorded, or every
    /// recorded entry has been cleared by a subsequent successful sync).
    public var hasAnySyncError: Bool {
        lastErrors.withLock { !$0.isEmpty }
    }

    public func cancelCurrentSync() {
        let cancel = state.withLock { $0.cancelCurrentSync }
        cancel?()
    }

    /// Handles a CloudKit silent push by routing directly to `cloudSync.synchronize(fromPush: true)`,
    /// bypassing the container's in-flight debounce. The `fromPush: true` flag has load-bearing
    /// semantics inside `SyncHandler.synchronize`: when a sync is already in progress AND its
    /// fetch phase has started, the flag triggers `needsResync = true` so the in-flight sync
    /// queues a follow-up pass on completion — without it, the push is silently dropped and
    /// the remote changes the push announced wait until the next user-driven trigger.
    ///
    /// Routing through `syncAll()` would not preserve this: the container's `reserveSyncSlot()`
    /// drops the trigger before it ever reaches `cloudSync`, and `CloudSyncAdapter.performSync`
    /// internally calls `synchronize(fromPush: false)`, so the flag is unreachable from the
    /// orchestrated path.
    ///
    /// CloudKit pushes are inherently iCloud-only (no equivalent for WebDAV / S3), so the
    /// method is named for the trigger (`handlePush`) rather than the backend. No-op when
    /// `setup(...)` hasn't run yet, or when `cloudSync.setup(...)` early-returned because
    /// deviceID was nil at launch — `cloudSync.synchronize` itself optional-chains through
    /// an unconfigured `cloudHandler`.
    public func handlePush() {
        cloudSync.synchronize(fromPush: true)
    }

    /// Cancels the running sync only if `id` is currently among `activeConfigIDs` — the per-id
    /// counterpart to `cancelCurrentSync()`. Backs the per-row "Cancel" button so a tap on one
    /// row doesn't tear down a sync that's already moved past it (or one that's running for a
    /// different config altogether).
    ///
    /// **Cancellation granularity.** The session runs services sequentially through a single
    /// `Task`, so cancelling at all means cancelling the whole session — there is no
    /// per-service interruption hook. In practice that matches the UI: per-row triggers go
    /// through `sync(_:)` (single-id session, so the only active id is the one we're
    /// cancelling), and `syncAll` runs at most one id active at a time. No-op when `id` isn't
    /// active — the running sync is for some other config and shouldn't be torn down by this
    /// caller's intent.
    public func cancelSync(id: UUID) {
        let cancel = state.withLock { state in
            state.activeConfigIDs.contains(id) ? state.cancelCurrentSync : nil
        }
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
        // Error tracking: separate critical section from `state` because the two have no
        // shared invariants. The session emits exactly one `.finished` per service per pass,
        // so writes are naturally serialized — no need to widen the `state` lock.
        if case .finished(let id, _, let outcome) = event {
            switch outcome {
            case .success:
                lastErrors.withLock { $0[id] = nil }
            case .failure(.cancelled):
                // User-initiated cancel: not an error worth surfacing. Leave any prior recorded
                // error in place — the cancel didn't change whether the underlying problem
                // (network down, bad credentials, …) is still present.
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
