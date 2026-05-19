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

    var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> {
        userDefaultsDataSource.vaultOverrideAwaitingConfigIDs
    }

    func markVaultOverrideAwaiting(configIDs: Set<BackupConfig.ID>) {
        // Additive merge: a second password-change-then-add-config sequence shouldn't drop
        // ids the first one already marked. The global progress observer is responsible for
        // removing entries; callers only ever insert.
        let merged = userDefaultsDataSource.vaultOverrideAwaitingConfigIDs.union(configIDs)
        userDefaultsDataSource.saveVaultOverrideAwaitingConfigIDs(merged)
    }

    func clearVaultOverrideAwaiting(configID: BackupConfig.ID) {
        var current = userDefaultsDataSource.vaultOverrideAwaitingConfigIDs
        guard current.remove(configID) != nil else { return }
        userDefaultsDataSource.saveVaultOverrideAwaitingConfigIDs(current)
    }

    var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> {
        userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs
    }

    func markDeviceRegistrationAwaiting(configIDs: Set<BackupConfig.ID>) {
        // Additive merge — same shape as `markVaultOverrideAwaiting`. Concurrent recovery
        // flows for different configs are vanishingly rare, but the merge keeps the rule
        // "callers only ever insert; the success path removes" symmetrical with the sister
        // override flag.
        let merged = userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs.union(configIDs)
        userDefaultsDataSource.saveDeviceRegistrationAwaitingConfigIDs(merged)
    }

    func clearDeviceRegistrationAwaiting(configID: BackupConfig.ID) {
        var current = userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs
        guard current.remove(configID) != nil else { return }
        userDefaultsDataSource.saveDeviceRegistrationAwaitingConfigIDs(current)
    }

    // MARK: - Backup Sync Container
    //
    // Known retain cycle: `MainRepository → container → adapter → MainRepository`. The adapter
    // retains `MainRepository` strongly. Benign today because `MainRepository` is the
    // `static var _shared` singleton; if that ever becomes per-session the cycle becomes a
    // real leak and must be broken (move container ownership out of `MainRepository`, or
    // weak-ref `MainRepository` from the adapter).

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

    func loadLastSyncDates() -> [BackupConfig.ID: Date] {
        guard let data = userDefaultsDataSource.lastSyncDatesBlob else { return [:] }
        return (try? jsonDecoder.decode([BackupConfig.ID: Date].self, from: data)) ?? [:]
    }

    func saveLastSyncDates(_ dates: [BackupConfig.ID: Date]) {
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

    func migrateLegacyBackupConfigs() {
        let legacyWebDAV = legacyWebDAVSavedConfig
        let legacyiCloudEnabled = userDefaultsDataSource.legacyCloudEnabled

        // Short-circuit when there's nothing to migrate. Avoids a `loadBackupConfigs`
        // decrypt round-trip on the common post-migration / fresh-install paths.
        guard legacyWebDAV != nil || legacyiCloudEnabled else { return }

        var configs = loadBackupConfigs()
        var dirty = false

        if let legacyWebDAV, configs.webDAVEntries.isEmpty {
            configs.append(.webDAV(BackupConfigEntry(id: BackupConfig.ID(), createdAt: Date(), config: legacyWebDAV)))
            dirty = true
        }

        if legacyiCloudEnabled, !configs.hasICloud {
            configs.append(.iCloud(BackupConfigEntry(id: BackupConfig.ID(), createdAt: Date(), config: BackupiCloudConfig())))
            dirty = true
        }

        if dirty {
            saveBackupConfigs(configs)
        }

        // Always clear the WebDAV blob if it was present, even when dedupe skipped the
        // append — clearing is the WebDAV migration's idempotency mechanism for future runs.
        // The iCloud flag stays put on purpose: `CloudHandler.isEnabled` still reads it.
        if legacyWebDAV != nil {
            clearLegacyWebDAVSavedConfig()
        }
    }

    // MARK: - Recovery form cache (in-memory)
    //
    // Owns the full encode-and-encrypt pipeline for the user's last-validated S3 / WebDAV
    // recovery config — identical shape to `saveBackupConfigs` / `loadBackupConfigs` above,
    // minus the UserDefaults read/write. Callers exchange the strongly-typed configs;
    // storage holds AES-GCM ciphertext under the Secure-Enclave appKey of the JSON-encoded
    // config. Cleared by `persistRecoverySource` on disk save and by both
    // `OnboardingInteractor.finishVault*` calls; otherwise dies with the process.
    //
    // The strongly-typed configs cross the API boundary only at the call site that just
    // produced one (`VaultRecoveryS3Presenter.onSave` / `WebDAVPresenter.onSave`) or the
    // call site that immediately consumes one
    // (`VaultRecoveryRecoverModuleInteractor.persistRecoverySource`).
    // Returns `nil` on any failure (no cache, no appKey, decrypt error, decode error) —
    // callers tolerate nil exactly like `loadBackupConfigs` does.

    var cachedS3RecoveryConfig: S3ServiceConfig? {
        guard let blob = _cachedS3RecoveryConfig,
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let plaintext = decrypt(blob, key: symmetricKey)
        else { return nil }
        return try? jsonDecoder.decode(S3ServiceConfig.self, from: plaintext)
    }

    var cachedWebDAVRecoveryConfig: BackupWebDAVConfig? {
        guard let blob = _cachedWebDAVRecoveryConfig,
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let plaintext = decrypt(blob, key: symmetricKey)
        else { return nil }
        return try? jsonDecoder.decode(BackupWebDAVConfig.self, from: plaintext)
    }

    func saveCachedS3RecoveryConfig(_ config: S3ServiceConfig) {
        guard let plaintext = try? jsonEncoder.encode(config),
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let encrypted = encrypt(plaintext, key: symmetricKey)
        else { return }
        _cachedS3RecoveryConfig = encrypted
    }

    func saveCachedWebDAVRecoveryConfig(_ config: BackupWebDAVConfig) {
        guard let plaintext = try? jsonEncoder.encode(config),
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let encrypted = encrypt(plaintext, key: symmetricKey)
        else { return }
        _cachedWebDAVRecoveryConfig = encrypted
    }

    func clearCachedRecoveryConfigs() {
        _cachedS3RecoveryConfig = nil
        _cachedWebDAVRecoveryConfig = nil
    }
}
