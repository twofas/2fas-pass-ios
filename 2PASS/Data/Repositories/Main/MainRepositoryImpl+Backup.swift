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
        // Additive merge: a second sequence shouldn't drop ids the first one already marked.
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
        let merged = userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs.union(configIDs)
        userDefaultsDataSource.saveDeviceRegistrationAwaitingConfigIDs(merged)
    }

    func clearDeviceRegistrationAwaiting(configID: BackupConfig.ID) {
        var current = userDefaultsDataSource.deviceRegistrationAwaitingConfigIDs
        guard current.remove(configID) != nil else { return }
        userDefaultsDataSource.saveDeviceRegistrationAwaitingConfigIDs(current)
    }

    // MARK: - Backup Sync Container

    // MARK: - Backup Sync config persistence

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

    // MARK: - Last sync dates

    func loadLastSyncDates() -> [BackupConfig.ID: Date] {
        guard let data = userDefaultsDataSource.lastSyncDatesBlob else { return [:] }
        return (try? jsonDecoder.decode([BackupConfig.ID: Date].self, from: data)) ?? [:]
    }

    func saveLastSyncDates(_ dates: [BackupConfig.ID: Date]) {
        guard let data = try? jsonEncoder.encode(dates) else { return }
        userDefaultsDataSource.saveLastSyncDatesBlob(data)
    }

    // MARK: - Legacy single-config migration

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

        if legacyWebDAV != nil {
            clearLegacyWebDAVSavedConfig()
        }
    }

    // MARK: - Recovery form cache (in-memory)

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
