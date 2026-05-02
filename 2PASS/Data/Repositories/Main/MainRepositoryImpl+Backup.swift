// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

extension MainRepositoryImpl {
    var webDAVSeedHash: String? {
        guard let vaultID = _selectedVault?.vaultID,
              let seed,
              let seedHashHex = generateExchangeSeedHash(vaultID, using: seed)
        else {
            return nil
        }

        return seedHashHex
    }

    var webDAVCurrentVaultID: VaultID? {
        _selectedVault?.vaultID
    }

    var webDAVWriteDecryptedCopy: Bool {
        userDefaultsDataSource.webDAVWriteDecryptedCopy
    }

    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool) {
        userDefaultsDataSource.webDAVSetWriteDecryptedCopy(writeDecryptedCopy)
    }

    var vaultOverrideAwaitingConfigIDs: Set<UUID> {
        userDefaultsDataSource.vaultOverrideAwaitingConfigIDs
    }

    func markVaultOverrideAwaiting(configIDs: Set<UUID>) {
        // Additive merge: a second password-change-then-add-config sequence shouldn't drop
        // ids the first one already marked. The global progress observer is responsible for
        // removing entries; callers only ever insert.
        let merged = userDefaultsDataSource.vaultOverrideAwaitingConfigIDs.union(configIDs)
        userDefaultsDataSource.saveVaultOverrideAwaitingConfigIDs(merged)
    }

    func clearVaultOverrideAwaiting(configID: UUID) {
        var current = userDefaultsDataSource.vaultOverrideAwaitingConfigIDs
        guard current.remove(configID) != nil else { return }
        userDefaultsDataSource.saveVaultOverrideAwaitingConfigIDs(current)
    }

    var deviceRegistrationAwaitingConfigIDs: Set<UUID> {
        userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs
    }

    func markDeviceRegistrationAwaiting(configIDs: Set<UUID>) {
        // Additive merge — same shape as `markVaultOverrideAwaiting`. Concurrent recovery
        // flows for different configs are vanishingly rare, but the merge keeps the rule
        // "callers only ever insert; the success path removes" symmetrical with the sister
        // override flag.
        let merged = userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs.union(configIDs)
        userDefaultsDataSource.saveDeviceRegistrationAwaitingConfigIDs(merged)
    }

    func clearDeviceRegistrationAwaiting(configID: UUID) {
        var current = userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs
        guard current.remove(configID) != nil else { return }
        userDefaultsDataSource.saveDeviceRegistrationAwaitingConfigIDs(current)
    }

    // MARK: - Backup Sync Container
    //
    // The container is a `let` stored property on `MainRepositoryImpl` itself (declared in
    // `MainRepositoryImpl.swift`) — single instance for the process lifetime, present from
    // birth, non-optional. This file used to host a getter+setter pair for an Optional that
    // was pushed in by `BackupSyncSetupInteractor.initialize()`; that flow is gone now.
    // Two-phase init handles the dependency cycle: `init()` builds an inert container,
    // `setup(...)` wires its collaborators afterwards from the interactor layer.
    //
    // The cycle `MainRepository → container → adapter → MainRepository` is unchanged — the
    // adapter still retains `MainRepository` strongly. Today this is benign because
    // `MainRepository` is the `static var _shared` singleton; if that ever becomes per-session
    // the cycle becomes a real leak and must be broken (move container ownership out of
    // `MainRepository`, or weak-ref `MainRepository` from the adapter).

    // MARK: - Backup Sync config persistence
    //
    // Owns the full persistence boundary: the unified `[BackupConfig]` list is JSON-encoded,
    // encrypted with a Secure Enclave-derived key, and stored as one UserDefaults blob.
    // Reading reverses the chain. Saving an empty array clears the stored blob (decoding back
    // yields `[]`).
    //
    // Failures (no `appKey`, enclave unavailable, decode mismatch) return an empty array on
    // load and silently no-op on save. The logged-out / not-set-up state is the only expected
    // failure mode; everything else is a corrupted-state bug.

    func loadBackupConfigs() -> [BackupConfig] {
        guard let data = userDefaultsDataSource.backupConfigsBlob,
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let plaintext = decrypt(data, key: symmetricKey)
        else { return [] }
        return (try? jsonDecoder.decode([BackupConfig].self, from: plaintext)) ?? []
    }

    func saveBackupConfigs(_ configs: [BackupConfig]) {
        guard let plaintext = try? jsonEncoder.encode(configs),
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let encrypted = encrypt(plaintext, key: symmetricKey)
        else { return }
        userDefaultsDataSource.saveBackupConfigsBlob(encrypted)
    }

    // MARK: - Last sync dates (plaintext)
    //
    // Per-config success timestamps. Stored as a JSON `[UUID: Date]` blob in UserDefaults
    // without encryption — timestamps are not sensitive, and dropping the Secure Enclave path
    // means reads succeed regardless of auth state. Returns an empty map on any failure
    // (no blob, decode mismatch).

    func loadLastSyncDates() -> [UUID: Date] {
        guard let data = userDefaultsDataSource.lastSyncDatesBlob else { return [:] }
        return (try? jsonDecoder.decode([UUID: Date].self, from: data)) ?? [:]
    }

    func saveLastSyncDates(_ dates: [UUID: Date]) {
        guard let data = try? jsonEncoder.encode(dates) else { return }
        userDefaultsDataSource.saveLastSyncDatesBlob(data)
    }

    // MARK: - Legacy single-config migration
    //
    // The pre-multi-config persistence stored exactly one `BackupWebDAVConfig` per app, no
    // UUID and no `createdAt`. Migration code reads this once, wraps the config into the new
    // unified list, then clears the legacy blob so the path becomes a no-op forever.

    var legacyWebDAVSavedConfig: BackupWebDAVConfig? {
        guard let data = userDefaultsDataSource.legacyWebDAVSavedConfig,
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let plaintext = decrypt(data, key: symmetricKey)
        else { return nil }
        return try? jsonDecoder.decode(BackupWebDAVConfig.self, from: plaintext)
    }

    func clearLegacyWebDAVSavedConfig() {
        userDefaultsDataSource.clearLegacyWebDAVSavedConfig()
    }
}
