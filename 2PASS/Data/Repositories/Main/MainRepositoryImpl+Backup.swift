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
    
    var webDAVSavedConfig: BackupWebDAVConfig? {
        guard let data = userDefaultsDataSource.webDAVSavedConfig,
              let appKey,
              let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
              let decoded = decrypt(data, key: symmetricKey)
        else { return nil }
        
        return try? jsonDecoder.decode(BackupWebDAVConfig.self, from: decoded)
    }
    
    func webDAVSaveSavedConfig(_ config: BackupWebDAVConfig) {
        guard let data = try? jsonEncoder.encode(config),
            let appKey,
            let symmetricKey = createSymmetricKeyFromSecureEnclave(from: appKey),
            let encoded = encrypt(data, key: symmetricKey)
        else { return }
        
        userDefaultsDataSource.saveWebDAVSavedConfig(encoded)
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
    
    func webDAVEncodeIndex(_ index: WebDAVIndex) -> Data? {
        try? jsonEncoder.encode(index)
    }
    
    func webDAVDecodeIndex(_ data: Data) -> WebDAVIndex? {
        try? jsonDecoder.decode(WebDAVIndex.self, from: data)
    }
    
    func webDAVClearConfig() {
        userDefaultsDataSource.clearWebDAVConfig()
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
}
