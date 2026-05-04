// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

/// **Hexagonal-architecture adapter** that fulfills the backup-sync collaborator ports —
/// `BackupSyncContext`, `BackupVaultExporting`, `BackupLocalMerging`, the persisted
/// `BackupSyncConfigStore` / `BackupSyncDateStore`, plus the awaiting-flag store
/// (`BackupAwaitingFlagsStoring`) — over the app's existing `MainRepository` +
/// callback-based interactor stack. A single instance is constructed by
/// `BackupSyncSetupInteractor.initialize()` and registered with the long-lived
/// `BackupSyncContainer`, which in turn passes it through to each per-call `BackupSyncSession`.
///
/// ## Why one class, not three
///
/// Each of the three ports represents a distinct role (read-only context metadata, vault export,
/// local merge), but every realistic implementation shares the same dependencies: `MainRepository`
/// for context state plus the trio of interactors (`ExportInteracting`, `BackupImportInteracting`,
/// `SyncInteracting`) for the work itself. Splitting the adapter into three classes would
/// duplicate that dependency graph; merging lets the container hold a single reference for all
/// three roles and keeps the `@unchecked Sendable` boundary defined exactly once.
///
/// ## Layering
///
/// Lives in `Data/BackupServices/`, not `Data/Interactors/`, because it isn't feature/UI business
/// logic — it's cross-cutting infrastructure that wires `MainRepository` and the interactor stack
/// to the async port protocols (defined in the `Backup` module).
///
/// Dependency direction: `BackupSyncSetupInteractor` (an interactor) builds the adapter and the
/// container, then pushes the container into `MainRepository` via a setter. `MainRepository`
/// itself neither constructs this class nor imports anything from this layer — only reads
/// flow upward, only construction flows downward.
///
/// ## Strong reference and the deliberate cycle
///
/// `mainRepository` is held strongly. The chain
/// `MainRepository → container → adapter → MainRepository` is a real strong retain cycle. Today
/// `MainRepository` is a process-lifetime singleton (`MainRepositoryImpl._shared`) and never
/// deallocates, so the cycle is benign — "everything lives forever" is the same outcome with or
/// without it. The matching caveat is documented next to `_backupSyncContainer` in
/// `MainRepositoryImpl+Backup.swift`: when `MainRepository` becomes per-user-session, the cycle
/// becomes a real leak and must be broken — either restore a `weak` reference here, or move
/// strong ownership of the container out of `MainRepository` into a session-scoped container.
///
/// ## Sendable contract
///
/// The held interactors (`ExportInteracting`, `BackupImportInteracting`, `SyncInteracting`) are
/// `AnyObject`-bound protocols not declared `Sendable`. This class is `@unchecked Sendable` on
/// the strength of two invariants the codebase already maintains:
///
/// 1. **Interactors are stateless service objects.** They hold references to `MainRepository`
///    and other interactors and delegate all real work; they keep no mutable cross-call state.
/// 2. **The container debounces overlapping triggers.** `BackupSyncContainer.acquireSyncSlot()`
///    holds an `OSAllocatedUnfairLock`-guarded boolean that drops a second trigger while a
///    sync is in flight. Each `syncAll` / `sync(_:)` call builds a fresh single-use
///    `BackupSyncSession` whose `run()` executes services serially. Together that means calls
///    into this adapter are never parallel — there is only ever one in-flight
///    `prepareEncryptedExport` / `applyRemoteChanges` across the whole sync subsystem.
///
/// Both are preconditions, not guarantees. If a future change introduces mutable cross-call
/// state into one of the held interactors, or removes the container's debounce, the
/// `@unchecked Sendable` here becomes unsafe and must be re-audited.
final class BackupSyncAdapter: BackupSyncContext, BackupVaultExporting, BackupLocalMerging, BackupSyncConfigStore, BackupSyncDateStore, BackupAwaitingFlagsStoring, @unchecked Sendable {

    private let mainRepository: MainRepository
    private let exportInteractor: ExportInteracting
    private let backupImportInteractor: BackupImportInteracting
    private let syncInteractor: SyncInteracting

    init(
        mainRepository: MainRepository,
        exportInteractor: ExportInteracting,
        backupImportInteractor: BackupImportInteracting,
        syncInteractor: SyncInteracting
    ) {
        self.mainRepository = mainRepository
        self.exportInteractor = exportInteractor
        self.backupImportInteractor = backupImportInteractor
        self.syncInteractor = syncInteractor
    }

    // MARK: - BackupSyncContext

    var deviceID: UUID? {
        mainRepository.deviceID
    }

    var deviceName: String {
        mainRepository.deviceName
    }

    var allowsMultiDeviceSync: Bool {
        mainRepository.paymentSubscriptionPlan.entitlements.multiDeviceSync
    }

    var vaultID: UUID? {
        mainRepository.selectedVault?.vaultID
    }

    func vault(for vaultID: UUID) async -> VaultEncryptedData? {
        await MainActor.run {
            mainRepository.getEncryptedVault(for: vaultID)
        }
    }

    func seedHash(for vaultID: UUID) -> String? {
        guard let seed = mainRepository.seed else { return nil }
        return mainRepository.generateExchangeSeedHash(vaultID, using: seed)
    }

    func latestContentModification(for vaultID: UUID) async -> Date? {
        await MainActor.run {
            let vaultUpdatedAt = mainRepository.getEncryptedVault(for: vaultID)?.updatedAt
            let itemMax = mainRepository.listEncryptedItems(in: vaultID).lazy.map(\.modificationDate).max()
            let tagMax = mainRepository.listEncryptedTags(in: vaultID).lazy.map(\.modificationDate).max()
            let deletedMax = mainRepository.listDeletedItems(in: vaultID, limit: nil).lazy.map(\.deletedAt).max()
            return [vaultUpdatedAt, itemMax, tagMax, deletedMax].compactMap { $0 }.max()
        }
    }

#if DEBUG
    var shouldWriteDecryptedCopy: Bool {
        mainRepository.webDAVWriteDecryptedCopy
    }
#endif

    // MARK: - BackupVaultExporting
    //
    // Encode round-trip: `ExportInteractor.prepareItemsForExport` JSON-encodes the vault to
    // `Data`. We decode it back into `ExchangeVault` to satisfy the protocol's typed return, and
    // `BackupFileSyncSession.prepareEncryptedExport` then JSON-encodes it again before upload.
    // Wasteful but transitional — future optimization: add an `ExportInteracting` method that
    // returns `ExchangeVault` directly.
    //
    // The `vaultID` parameter is currently ignored because `ExportInteracting` always exports
    // `mainRepository.selectedVault`. TODO once the app supports multiple vaults.

    func prepareEncryptedExport(
        vaultID: UUID,
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault {
        try await runExport(encrypt: true, includeDeleted: includeDeleted)
    }

#if DEBUG
    func prepareDecryptedExport(
        vaultID: UUID,
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault {
        try await runExport(encrypt: false, includeDeleted: includeDeleted)
    }
#endif

    private func runExport(
        encrypt: Bool,
        includeDeleted: Bool
    ) async throws(BackupVaultExportError) -> ExchangeVault {
        let result: Result<(Data, String), ExportError> = await withCheckedContinuation { continuation in
            exportInteractor.prepareItemsForExport(
                encrypt: encrypt,
                exportIfEmpty: true,
                includeDeletedItems: includeDeleted
            ) { result in
                continuation.resume(returning: result)
            }
        }

        switch result {
        case .success(let (data, _)):
            do {
                return try JSONDecoder().decode(ExchangeVault.self, from: data)
            } catch {
                throw .other("export decode: \(error)")
            }
        case .failure(let error):
            throw Self.mapExportError(error)
        }
    }

    private static func mapExportError(_ error: ExportError) -> BackupVaultExportError {
        switch error {
        case .noItemsToExport:
            return .empty
        case .noSelectedVault:
            return .other("no selected vault")
        case .missingExternalKey, .encryptionDef:
            return .encryptionFailed
        case .jsonEncode(let underlying):
            return .other("export encode: \(underlying)")
        case .jsonDecode(let underlying):
            return .other("export decode: \(underlying.map(String.init(describing:)) ?? "nil")")
        }
    }

    // MARK: - BackupLocalMerging
    //
    // Encode round-trip: `BackupImportInteracting.parseContents` takes raw `Data`, but the
    // coordinator hands us an already-decoded `ExchangeVaultVersioned`. We re-encode the typed
    // value back to `Data` so the legacy parser can decode it again.
    //
    // Mutation accuracy: the returned `Bool` mirrors `SyncInteractor.syncAndApplyChanges`'s
    // own change-tracking arrays — `true` only when at least one item, tag, or deleted-tombstone
    // row was added, modified, or removed. Genuine no-op merges (remote ≡ local, or remote
    // strictly older) return `false`, so `BackupSyncSession`'s convergence loop does not
    // re-queue peer services unnecessarily. The local push in `BackupFileSyncSession.runAttempt`
    // happens unconditionally, so an accurate `false` is safe here — it never gates the push.

    func applyRemoteChanges(
        _ remoteVault: ExchangeVaultVersioned,
        allowingAnyDeviceId: Bool
    ) async throws(BackupLocalMergeError) -> Bool {
        let data: Data
        do {
            data = try Self.encode(remoteVault)
        } catch {
            // We just produced this from a typed value; encoding shouldn't fail. Treat as a
            // decryption-class failure to abort the sync cleanly.
            throw .errorDecrypting
        }

        let result: Result<BackupImportResult, BackupImportParseError> = await withCheckedContinuation { continuation in
            backupImportInteractor.parseContents(
                of: data,
                decryptItemsIfPossible: true,
                allowsAnyDeviceId: allowingAnyDeviceId
            ) { result in
                continuation.resume(returning: result)
            }
        }

        switch result {
        case .success(let parsed):
            switch parsed {
            case .decrypted(let items, let tags, let deleted, _, _, _, _):
                return await MainActor.run {
                    syncInteractor.syncAndApplyChanges(
                        from: items,
                        externalTags: tags,
                        externalDeleted: deleted
                    )
                }
            case .needsPassword:
                throw .needsPassword
            }
        case .failure(let error):
            switch error {
            case .errorDecrypting, .corruptedFile, .schemaNotSupported:
                // .corruptedFile and .schemaNotSupported are defensive: we just encoded a typed
                // value ourselves, so they shouldn't fire. If they do, surface as a decryption-
                // class failure so the sync attempt aborts cleanly.
                throw .errorDecrypting
            case .otherDeviceId:
                throw .otherDeviceId
            case .passwordChanged:
                throw .passwordChanged
            case .nothingToImport:
                // Genuinely no changes — not an error.
                return false
            }
        }
    }

    /// `ExchangeVaultVersioned` is `Decodable`-only; encode by switching on the case and encoding
    /// the inner v1/v2 struct. Each carries its own `schemaVersion` field so the round-trip
    /// decoder can route back to the right case.
    private static func encode(_ versioned: ExchangeVaultVersioned) throws -> Data {
        let encoder = JSONEncoder()
        switch versioned {
        case .v1(let vault):
            return try encoder.encode(vault)
        case .v2(let vault):
            return try encoder.encode(vault)
        }
    }

    // MARK: - BackupSyncConfigStore
    //
    // Pure forwarders. `MainRepository` owns encryption + JSON encoding; the adapter exists
    // here only to expose the methods through the `BackupSyncConfigStore` protocol seam.

    func loadConfigs() -> [BackupConfig] {
        mainRepository.loadBackupConfigs()
    }

    func saveConfigs(_ configs: [BackupConfig]) {
        mainRepository.saveBackupConfigs(configs)
    }

    // MARK: - BackupSyncDateStore
    //
    // `lastSyncDate(for:)` is a pure read-through forwarder. `setLastSyncDate(_:for:consumed:)`
    // does two things: stamps the success timestamp AND conditionally clears per-config
    // awaiting-flags based on what the sync actually honored (see the `consumed` parameter
    // below). The sync engine (`BackupFileSyncSession.performSync`, `CloudSyncAdapter.performSync`)
    // calls this method exactly once per successful sync, so it's the synchronous pivot
    // point for "this config no longer needs X next time" — closer to the success signal
    // than an external `syncEvents()` observer would be, with no async race window
    // between sync completion and a concurrent flag-set call (e.g. `passwordWasChanged`
    // marking mid-sync).

    func lastSyncDate(for id: UUID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    func setLastSyncDate(_ date: Date, for id: UUID, consumed: BackupSyncFlags) {
        var dates = mainRepository.loadLastSyncDates()
        dates[id] = date
        mainRepository.saveLastSyncDates(dates)
        // Conditional clears on the awaiting-sets: each one is only cleared when the
        // just-completed sync actually honored the flag. The unconditional version had a
        // race — a routine sync that finished *after* a password change marked the flag
        // (but didn't itself overwrite, since it captured the pre-change snapshot via the
        // container's per-id closure) would wipe a flag whose work hadn't been performed.
        // With `consumed`, the cancel-and-retry flow's pre-change sync exits here with
        // `consumed.overwritingVault == false` and leaves the freshly-set flag alone for
        // the retry to consume.
        if consumed.overwritingVault {
            mainRepository.clearVaultOverrideAwaiting(configID: id)
        }
        if consumed.allowingAnyDeviceId {
            mainRepository.clearDeviceRegistrationAwaiting(configID: id)
        }
    }

    // MARK: - BackupAwaitingFlagsStoring
    //
    // Pure forwarders to `MainRepository`'s persistent awaiting-flag storage (UserDefaults-
    // backed). The container reads these via the snapshot taken inside `syncAll()` /
    // `sync(_:)`; mutations come from password-change and recovery flows through the
    // container's public `markX` surface, which routes here. Clearing happens just above
    // in `setLastSyncDate(_:for:consumed:)` and goes directly through `MainRepository`,
    // bypassing this protocol — both paths land in the same UserDefaults keys.

    var vaultOverrideAwaitingConfigIDs: Set<UUID> {
        mainRepository.vaultOverrideAwaitingConfigIDs
    }

    func markVaultOverrideAwaiting(configIDs: Set<UUID>) {
        mainRepository.markVaultOverrideAwaiting(configIDs: configIDs)
    }

    var deviceRegistrationAwaitingConfigIDs: Set<UUID> {
        mainRepository.deviceRegistrationAwaitingConfigIDs
    }

    func markDeviceRegistrationAwaiting(configIDs: Set<UUID>) {
        mainRepository.markDeviceRegistrationAwaiting(configIDs: configIDs)
    }
}
