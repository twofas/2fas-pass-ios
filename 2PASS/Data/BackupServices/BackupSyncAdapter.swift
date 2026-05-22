// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

/// Adapter that fulfills the Backup module's collaborator ports (`BackupSyncContext`,
/// `BackupVaultExporting`, `BackupLocalMerging`, `BackupSyncConfigStore`,
/// `BackupSyncDateStore`, `BackupAwaitingFlagsStoring`) over `MainRepository` plus the
/// callback-based interactor stack.
///
/// **One class, not three.** Every realistic implementation of these ports shares the same
/// dependencies; splitting would duplicate the dependency graph and the `@unchecked Sendable`
/// boundary. Lives in `Data/BackupServices/` because it's cross-cutting infrastructure, not
/// feature/UI business logic.
///
/// **Strong reference to `mainRepository`.** The chain
/// `MainRepository → container → adapter → MainRepository` is a real strong retain cycle.
/// Today `MainRepository` is a process-lifetime singleton so the cycle is benign. If
/// `MainRepository` becomes per-user-session, this must be broken — either `weak` here or
/// move container ownership out of `MainRepository`.
///
/// **`@unchecked Sendable` invariants.** Two preconditions the codebase already maintains:
/// 1. The held interactors are stateless service objects (no mutable cross-call state).
/// 2. `BackupSyncContainer` debounces overlapping triggers, so calls into this adapter are
///    never parallel.
///
/// If a future change adds mutable state to a held interactor or removes the container's
/// debounce, this annotation becomes unsafe and must be re-audited.
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
            let vault = mainRepository.getEncryptedVault(for: vaultID)
            return [vault?.updatedAt, vault?.contentModificationDate].compactMap { $0 }.max()
        }
    }

#if DEBUG
    var shouldWriteDecryptedCopy: Bool {
        mainRepository.webDAVWriteDecryptedCopy
    }
#endif

    // MARK: - BackupVaultExporting
    //
    // `ExportInteractor.prepareItemsForExport` JSON-encodes to `Data`; we decode back to
    // `ExchangeVault` to satisfy the typed return, and the caller re-encodes before upload.
    // Transitional; future cleanup: add an `ExportInteracting` method returning `ExchangeVault`.
    // `vaultID` is ignored — `ExportInteracting` always exports `mainRepository.selectedVault`.

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
    // `parseContents` takes `Data` but we get a decoded `ExchangeVaultVersioned`, so we
    // re-encode. The returned `Bool` mirrors `SyncInteractor.syncAndApplyChanges`'s own
    // change tracking — `true` only on real mutations; the convergence loop relies on an
    // accurate `false` to avoid re-queueing peers. The local push happens unconditionally,
    // so `false` is safe to return on a no-op merge.

    func applyRemoteChanges(
        _ remoteVault: ExchangeVaultVersioned,
        allowingAnyDeviceId: Bool
    ) async throws(BackupLocalMergeError) -> Bool {
        let data: Data
        do {
            data = try Self.encode(remoteVault)
        } catch {
            // Encoding a typed value we just produced shouldn't fail. Treat as decryption-class
            // failure so the sync attempt aborts cleanly.
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
                // .corruptedFile / .schemaNotSupported are defensive — we just encoded a
                // typed value ourselves. If they fire, surface as decryption-class failure.
                throw .errorDecrypting
            case .otherDeviceId:
                throw .otherDeviceId
            case .passwordChanged:
                throw .passwordChanged
            case .nothingToImport:
                return false
            }
        }
    }

    /// `ExchangeVaultVersioned` is `Decodable`-only; encode by switching on the case. Each
    /// inner struct carries its own `schemaVersion` so the decoder routes back correctly.
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

    func loadConfigs() -> [BackupConfig] {
        mainRepository.loadBackupConfigs()
    }

    func saveConfigs(_ configs: [BackupConfig]) {
        mainRepository.saveBackupConfigs(configs)
    }

    // MARK: - BackupSyncDateStore

    func lastSyncDate(for id: BackupConfig.ID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    /// Stamps the success timestamp AND clears per-config awaiting-flags only when the sync
    /// actually honored them. Conditional clears matter: a routine sync that finishes after
    /// a password-change mark (but captured the pre-change snapshot) would otherwise wipe a
    /// flag whose work hadn't been performed.
    func setLastSyncDate(_ date: Date, for id: BackupConfig.ID, consumed: BackupSyncFlags) {
        var dates = mainRepository.loadLastSyncDates()
        dates[id] = date
        mainRepository.saveLastSyncDates(dates)
        if consumed.overwritingVault {
            mainRepository.clearVaultOverrideAwaiting(configID: id)
        }
        if consumed.allowingAnyDeviceId {
            mainRepository.clearDeviceRegistrationAwaiting(configID: id)
        }
    }

    // MARK: - BackupAwaitingFlagsStoring

    var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> {
        mainRepository.vaultOverrideAwaitingConfigIDs
    }

    func markVaultOverrideAwaiting(configIDs: Set<BackupConfig.ID>) {
        mainRepository.markVaultOverrideAwaiting(configIDs: configIDs)
    }

    var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> {
        mainRepository.deviceRegistrationAwaitingConfigIDs
    }

    func markDeviceRegistrationAwaiting(configIDs: Set<BackupConfig.ID>) {
        mainRepository.markDeviceRegistrationAwaiting(configIDs: configIDs)
    }
}
