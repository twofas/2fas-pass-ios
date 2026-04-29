// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

/// **Hexagonal-architecture adapter** that fulfills `BackupSyncCoordinator`'s three collaborator
/// ports — `BackupSyncContext`, `BackupVaultExporting`, `BackupLocalMerging` — over the app's
/// existing `MainRepository` + callback-based interactor stack. A single instance is constructed
/// by `BackupSyncSetupInteractor.initialize()` and registered in all three
/// slots on the coordinator.
///
/// ## Why one class, not three
///
/// Each of the three ports represents a distinct role (read-only context metadata, vault export,
/// local merge), but every realistic implementation shares the same dependencies: `MainRepository`
/// for context state plus the trio of interactors (`ExportInteracting`, `BackupImportInteracting`,
/// `SyncInteracting`) for the work itself. Splitting the adapter into three classes would
/// duplicate that dependency graph; merging lets the coordinator hold a single reference for all
/// three roles and keeps the `@unchecked Sendable` boundary defined exactly once.
///
/// ## Layering
///
/// Lives in `Data/BackupServices/`, not `Data/Interactors/`, because it isn't feature/UI business
/// logic — it's cross-cutting infrastructure that wires `MainRepository` and the interactor stack
/// to the coordinator's async port protocols (defined in the `Backup` module).
///
/// Dependency direction: `BackupSyncSetupInteractor` (an interactor) builds the adapter and the
/// coordinator, then pushes the coordinator into `MainRepository` via a setter. `MainRepository`
/// itself neither constructs this class nor imports anything from this layer — only reads
/// flow upward, only construction flows downward.
///
/// ## Strong reference and the deliberate cycle
///
/// `mainRepository` is held strongly. The chain
/// `MainRepository → coordinator → adapter → MainRepository` is a real strong retain cycle. Today
/// `MainRepository` is a process-lifetime singleton (`MainRepositoryImpl._shared`) and never
/// deallocates, so the cycle is benign — "everything lives forever" is the same outcome with or
/// without it. The matching caveat is documented next to `_backupSyncContainer` in
/// `MainRepositoryImpl+Backup.swift`: when `MainRepository` becomes per-user-session, the cycle
/// becomes a real leak and must be broken — either restore a `weak` reference here, or move
/// strong ownership of the coordinator out of `MainRepository` into a session-scoped container.
///
/// ## Sendable contract
///
/// The held interactors (`ExportInteracting`, `BackupImportInteracting`, `SyncInteracting`) are
/// `AnyObject`-bound protocols not declared `Sendable`. This class is `@unchecked Sendable` on
/// the strength of two invariants the codebase already maintains:
///
/// 1. **Interactors are stateless service objects.** They hold references to `MainRepository`
///    and other interactors and delegate all real work; they keep no mutable cross-call state.
/// 2. **The coordinator serializes its calls.** `BackupSyncCoordinator` is an actor with an
///    explicit task chain, so calls into this adapter are never parallel — there is only ever
///    one in-flight `prepareEncryptedExport` / `applyRemoteChanges` per coordinator instance.
///
/// Both are preconditions, not guarantees. If a future change introduces mutable cross-call
/// state into one of the held interactors, or removes the coordinator's serial queue, the
/// `@unchecked Sendable` here becomes unsafe and must be re-audited.
final class BackupSyncAdapter: BackupSyncContext, BackupVaultExporting, BackupLocalMerging, BackupSyncConfigStore, BackupSyncDateStore, @unchecked Sendable {

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

    func vault(for vaultID: UUID) -> VaultEncryptedData? {
        mainRepository.getEncryptedVault(for: vaultID)
    }

    func seedHash(for vaultID: UUID) -> String? {
        guard let seed = mainRepository.seed else { return nil }
        return mainRepository.generateExchangeSeedHash(vaultID, using: seed)
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
    // Optimistic-true: `SyncInteractor.syncAndApplyChanges` is synchronous and side-effecting,
    // does not report whether any rows actually mutated. We return `true` after a successful
    // merge regardless. The convergence loop in `BackupSyncCoordinator` tolerates the false
    // positive (one extra harmless pass). Returning `false` after a real merge would be
    // dangerous — the sync engine would push the unmerged-local state to the remote and
    // overwrite the freshly-fetched remote content, causing data loss.

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
                syncInteractor.syncAndApplyChanges(
                    from: items,
                    externalTags: tags,
                    externalDeleted: deleted
                )
                return true
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
    // Pure forwarders. The mutation does load-mutate-save inline since the protocol's API is
    // per-id, while the underlying persistence is a single `[UUID: Date]` blob.

    func lastSyncDate(for id: UUID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    func setLastSyncDate(_ date: Date, for id: UUID) {
        var dates = mainRepository.loadLastSyncDates()
        dates[id] = date
        mainRepository.saveLastSyncDates(dates)
    }
}
