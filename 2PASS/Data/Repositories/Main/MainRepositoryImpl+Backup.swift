// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

extension MainRepositoryImpl {
    func webDAVGetIndex(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.getIndex(completion: completion)
    }
    
    func webDAVGetLock(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.getLock(completion: completion)
    }
    
    func webDAVGetVault(completion: @escaping (Result<Data, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.getVault(completion: completion)
    }
    
    func webDAVWriteIndex(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.writeIndex(fileContents: fileContents, completion: completion)
    }
    
    func webDAVWriteLock(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.writeLock(fileContents: fileContents, completion: completion)
    }
    
    func webDAVWriteVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.writeVault(fileContents: fileContents, completion: completion)
    }
    
    func webDAVWriteDecryptedVault(fileContents: Data, completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.writeDecryptedVault(fileContents: fileContents, completion: completion)
    }

    
    func webDAVMove(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.move(completion: completion)
    }
    
    func webDAVDeleteLock(completion: @escaping (Result<Void, BackupWebDAVSyncError>) -> Void) {
        backupWebDAV.delete(completion: completion)
    }
    
    func webDAVSetBackupConfig(_ config: BackupWebDAVConfig) {
        backupWebDAV.setConfig(config)
    }
    
    func webDAVEncodeLock(timestamp: Int, deviceId: UUID = .init()) -> Data? {
        let data = WebDAVLock(deviceId: deviceId, timestamp: timestamp)
        return try? jsonEncoder.encode(data)
    }
    
    func webDAVDecodeLock(_ data: Data) -> (timestamp: Int, deviceId: UUID)? {
        guard let decoded = try? jsonDecoder.decode(WebDAVLock.self, from: data) else {
            return nil
        }
        return (timestamp: decoded.timestamp, deviceId: decoded.deviceId)
    }
    
    func webDAVEncodeIndex(_ index: BackupIndex) -> Data? {
        try? jsonEncoder.encode(index)
    }
    
    func webDAVDecodeIndex(_ data: Data) -> BackupIndex? {
        try? jsonDecoder.decode(BackupIndex.self, from: data)
    }
    
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
    
    var webDAVIsConnected: Bool {
        userDefaultsDataSource.webDAVIsConnected
    }
    
    func webDAVSetIsConnected(_ isConnected: Bool) {
        userDefaultsDataSource.webDAVSetIsConnected(isConnected)
    }
    
    func webDAVClearIsConnected() {
        userDefaultsDataSource.webDAVClearIsConnected()
    }
    
    var webDAVState: WebDAVState {
        _webDAVState
    }
    
    func webDAVSetState(_ state: WebDAVState) {
        _webDAVState = state
    }
    
    func webDAVClearState() {
        _webDAVState = .idle
    }
    
    var webDAVHasLocalChanges: Bool {
        userDefaultsDataSource.webDAVHasLocalChanges
    }
    
    func webDAVSetHasLocalChanges() {
        userDefaultsDataSource.webDAVSetHasLocalChanges()
    }
    
    func webDAVClearHasLocalChanges() {
        userDefaultsDataSource.webDAVClearHasLocalChanges()
    }
    
    var webDAVLastSync: WebDAVLock? {
        guard let state = userDefaultsDataSource.webDAVLastSync,
              let decoded = try? jsonDecoder.decode(WebDAVLock.self, from: state) else {
            return nil
        }
        return decoded
    }
    
    func webDAVSetLastSync(_ lastSync: WebDAVLock) {
        guard let data = try? jsonEncoder.encode(lastSync) else { return }
        userDefaultsDataSource.webDAVSetLastSync(data)
    }
    
    func webDAVClearLastSync() {
        userDefaultsDataSource.webDAVClearLastSync()
    }
    
    var webDAVWriteDecryptedCopy: Bool {
        userDefaultsDataSource.webDAVWriteDecryptedCopy
    }
    
    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool) {
        userDefaultsDataSource.webDAVSetWriteDecryptedCopy(writeDecryptedCopy)
    }
    
    var webDAVAwaitsVaultOverrideAfterPasswordChange: Bool {
        userDefaultsDataSource.webDAVAwaitsVaultOverrideAfterPasswordChange
    }

    func setWebDAVAwaitsVaultOverrideAfterPasswordChange(_ value: Bool) {
        userDefaultsDataSource.setWebDAVAwaitsVaultOverrideAfterPasswordChange(value)
    }

    // MARK: - Backup Sync Container
    //
    // Stored by value. The container itself is a `Sendable` struct, but it holds a registry
    // (actor) which holds the factory (struct) which holds the `BackupSyncAdapter` (class),
    // and that adapter retains `MainRepository`. The transitive chain
    // `MainRepository → container → registry → factory → adapter → MainRepository` is therefore
    // still a real strong retain cycle — value-typing the container does not break it. Today
    // `MainRepository` is `static var _shared` (singleton), so the cycle is benign — the
    // singleton never deallocates, and "everything lives forever" is the same outcome with or
    // without the cycle.
    //
    // **Caveat for a future per-session `MainRepository`.** When `_shared` is removed and
    // `MainRepository` becomes per-user-session, this cycle becomes a real leak: the session
    // graph would be retained beyond logout. At that point the cycle must be broken — either by
    // moving strong ownership of the container/registry out of `MainRepository` into a
    // logged-in-session container, or by reworking the adapter to hold `MainRepository` weakly.

    var backupSyncContainer: BackupSyncContainer? {
        _backupSyncContainer
    }

    func setBackupSyncContainer(_ container: BackupSyncContainer) {
        _backupSyncContainer = container
    }

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
