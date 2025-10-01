// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

public protocol WebDAVBackupInteracting: AnyObject {
    var hasConfiguration: Bool { get }
    func sync()
    func disconnect()
}

final class WebDAVBackupInteractor {
    private let mainRepository: MainRepository
    private let backupImportInteractor: BackupImportInteracting
    private let exportInteractor: ExportInteracting
    private let webDAVStateInteractor: WebDAVStateInteracting
    private let timerInteractor: TimerInteracting
    private let syncInteractor: SyncInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting

    private let noInternetRetry: Int = 10
    private let ignoreDeviceId: Bool
    
    private var syncAgain = false
    
    // Internal state during sync
    private var shouldStop = false
    private var overwriteVault = false
    private var fetchedIndex: WebDAVIndex?
    
    init(
        ignoreDeviceId: Bool = false,
        mainRepository: MainRepository,
        backupImportInteractor: BackupImportInteracting,
        exportInteractor: ExportInteracting,
        webDAVStateInteractor: WebDAVStateInteracting,
        timerInteractor: TimerInteracting,
        syncInteractor: SyncInteracting,
        paymentStatusInteractor: PaymentStatusInteracting
    ) {
        self.ignoreDeviceId = ignoreDeviceId
        self.mainRepository = mainRepository
        self.backupImportInteractor = backupImportInteractor
        self.exportInteractor = exportInteractor
        self.webDAVStateInteractor = webDAVStateInteractor
        self.timerInteractor = timerInteractor
        self.syncInteractor = syncInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
        
        timerInteractor.timerTicked = { [weak self] in self?.resume() }
    }
    
    deinit {
        timerInteractor.destroy()
    }
}

extension WebDAVBackupInteractor: WebDAVBackupInteracting {
    
    var hasConfiguration: Bool {
        webDAVStateInteractor.getConfig() != nil
    }
    
    func sync() {
        if webDAVStateInteractor.awaitsVaultOverrideAfterPasswordChange {
            overwriteVault = true
        }
        sync(isRetry: false)
    }
    
    func disconnect() {
        Log("WebDAVBackupInteractor - disconnecting", module: .interactor)
        timerInteractor.pause()
        if webDAVStateInteractor.isSyncing {
            Log("WebDAVBackupInteractor - is syncing. Setting shouldStop", module: .interactor)
            shouldStop = true
        } else {
            Log("WebDAVBackupInteractor - stopping", module: .interactor)
            stop()
        }
        webDAVStateInteractor.disconnect()
    }
}

private extension WebDAVBackupInteractor {
    
    func sync(isRetry: Bool) {
        Log("WebDAVBackupInteractor - entering sync", module: .interactor)
        guard !webDAVStateInteractor.isSyncing else {
            Log("WebDAVBackupInteractor - already syncing", module: .interactor)
            if webDAVStateInteractor.canResyncAutomatically {
                Log("WebDAVBackupInteractor - setting syncAgain", module: .interactor)
                syncAgain = true
            }
            return
        }
        
        guard let config = webDAVStateInteractor.getConfig() else {
            webDAVStateInteractor.syncError(.notConfigured)
            Log("WebDAVBackupInteractor - error. No webDAV config!", module: .interactor, severity: .error)
            return
        }
        
        mainRepository.webDAVSetBackupConfig(config)
        webDAVStateInteractor.startSync(isRetry: isRetry)
        Log("WebDAVBackupInteractor - getting index", module: .interactor)
        mainRepository.webDAVGetIndex { [weak self] result in
            switch result {
            case .success(let index):
                guard let index = self?.mainRepository.webDAVDecodeIndex(index) else {
                    Log("WebDAVBackupInteractor - index damaged. Overwriting lock", module: .interactor)
                    self?.createLock()
                    return
                }
                Log("WebDAVBackupInteractor - getting index success", module: .interactor)
                self?.parseIndex(index)
            case .failure(let error):
                switch error {
                case .unauthorized:
                    Log("WebDAVBackupInteractor - getting index error: unauthorized", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.unauthorized)
                case .forbidden:
                    Log("WebDAVBackupInteractor - getting index error: forbidden", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.forbidden)
                case .syncErrorTryingAgain:
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - getting index error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry()
                    } else {
                        Log("WebDAVBackupInteractor - getting index error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.syncError(nil))
                    }
                case .notFound:
                    Log("WebDAVBackupInteractor - no index. Setting lock", module: .interactor)
                    self?.createLock()
                case .syncError(let error):
                    Log("WebDAVBackupInteractor - getting index error: sync error: \(error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.syncError(error.localizedDescription))
                case .networkError(let error):
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - getting index network error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry(reason: error.localizedDescription, time: self?.noInternetRetry)
                    } else {
                        Log("WebDAVBackupInteractor - getting index network error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.networkError(error.localizedDescription))
                    }
                case .serverError(let error):
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - getting index server error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry(reason: error.localizedDescription)
                    } else {
                        Log("WebDAVBackupInteractor - getting index server error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.serverError(error.localizedDescription))
                    }
                case .urlError(let error):
                    Log("WebDAVBackupInteractor - getting index error: url error: \(error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.urlError(error.localizedDescription))
                case .sslError:
                    Log("WebDAVBackupInteractor - getting index error: SSL error", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.sslError)
                case .methodNotAllowed:
                    Log("WebDAVBackupInteractor - getting index error: method not allowed", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.methodNotAllowed)
                }
            }
        }
    }
    
    func parseIndex(_ index: WebDAVIndex) {
        Log("WebDAVBackupInteractor - parsing index", module: .interactor)
        guard !shouldStop else {
            stop()
            Log("WebDAVBackupInteractor - stopping parsing index", module: .interactor)
            return
        }
        guard let vid = mainRepository.selectedVault?.vaultID,
              let seedHash = mainRepository.webDAVSeedHash else {
            webDAVStateInteractor.syncError(.syncError(nil))
            Log("WebDAVBackupInteractor - error. No vaultID or seed hash", module: .interactor, severity: .error)
            return
        }
        
        fetchedIndex = index
        if let matchingVaultIndex = index.firstIndex(for: vid, seedHash: seedHash),
           let matchingVault = index.backups[safe: matchingVaultIndex] {
            Log("WebDAVBackupInteractor - matching vault found", module: .interactor)
            
            if matchingVault.schemaVersion > Config.indexSchemaVersion {
                Log(
                    "WebDAVBackupInteractor - Error: index schema version larger than supported.",
                    module: .interactor,
                    severity: .error
                )
                webDAVStateInteractor.syncError(.schemaNotSupported(matchingVault.schemaVersion))
                return
            }
            
            if let lastSyncTimestamp = webDAVStateInteractor.lastSyncTimestamp,
               lastSyncTimestamp == matchingVault.vaultUpdatedAt {
                Log("WebDAVBackupInteractor - date of last sync is the same as local one", module: .interactor)
                if mainRepository.webDAVHasLocalChanges {
                    Log("WebDAVBackupInteractor - there are local changes. Proceeding", module: .interactor)
                    checkLock()
                } else {
                    Log("WebDAVBackupInteractor - no local changes. Finishing", module: .interactor)
                    success()
                }
            } else { // first sync
                Log("WebDAVBackupInteractor - no sync date or diffrent than local: \(webDAVStateInteractor.lastSyncTimestamp ?? -1) vs. \(matchingVault.vaultUpdatedAt)", module: .interactor)
                checkLock()
            }
        } else {
            Log("WebDAVBackupInteractor - no matching vault found", module: .interactor)
            checkLock()
        }
    }
    
    func checkLock() {
        Log("WebDAVBackupInteractor - checking lock", module: .interactor)
        guard !shouldStop else {
            Log("WebDAVBackupInteractor - stopping lock check", module: .interactor)
            stop()
            return
        }
        
        mainRepository.webDAVGetLock { [weak self] result in
            switch result {
            case .success(let lock):
                Log("WebDAVBackupInteractor - lock exists", module: .interactor)
                guard let lock = self?.mainRepository.webDAVDecodeLock(lock),
                      let deviceId = self?.mainRepository.deviceID else {
                    Log("WebDAVBackupInteractor - file is damaged or nothing to compare to", module: .interactor)
                    self?.createLock()
                    return
                }
                if lock.deviceId == deviceId { // we didn't remove lock last time - overriding
                    Log("WebDAVBackupInteractor - it's our own from last unsuccessful sync. Overwriting", module: .interactor)
                    self?.createLock()
                } else {
                    let currentTimestamp = self?.mainRepository.currentDate.exportTimestamp ?? Date().exportTimestamp
                    if lock.timestamp + Config.webDAVLockFileTime > currentTimestamp || currentTimestamp - lock.timestamp < 4 * Config.webDAVLockFileTime {
                        Log("WebDAVBackupInteractor - Waiting for other client to finish", module: .interactor)
                        self?.retry(lock.timestamp + (Config.webDAVLockFileTime * 3) / 2)
                    } else {
                        Log("WebDAVBackupInteractor - other client left lock some time ago. Overwriting", module: .interactor)
                        self?.createLock()
                    }
                }
            case .failure(let error):
                switch error {
                case .unauthorized:
                    Log("WebDAVBackupInteractor - fetching lock error: unauthorized", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.unauthorized)
                case .forbidden:
                    Log("WebDAVBackupInteractor - fetching lock error: forbidden", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.forbidden)
                case .syncErrorTryingAgain:
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - fetching lock error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry()
                    } else {
                        Log("WebDAVBackupInteractor - fetching lock error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.syncError(nil))
                    }
                case .notFound:
                    Log("WebDAVBackupInteractor - no lock found. Creating", module: .interactor)
                    self?.createLock()
                case .syncError(let error):
                    Log("WebDAVBackupInteractor - fetching lock error: sync error \(error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.syncError(error.localizedDescription))
                case .networkError(let error):
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - fetching lock error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry(reason: error.localizedDescription, time: self?.noInternetRetry)
                    } else {
                        Log("WebDAVBackupInteractor - fetching lock error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.networkError(error.localizedDescription))
                    }
                case .serverError(let error):
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - fetching lock error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry(reason: error.localizedDescription)
                    } else {
                        Log("WebDAVBackupInteractor - fetching lock error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.serverError(error.localizedDescription))
                    }
                case .urlError(let error):
                    Log("WebDAVBackupInteractor - fetching lock error: url error: \(error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.urlError(error.localizedDescription))
                case .sslError:
                    Log("WebDAVBackupInteractor - fetching lock error: SSL error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.sslError)
                case .methodNotAllowed:
                    Log("WebDAVBackupInteractor - fetching lock error: method not allowed", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.methodNotAllowed)
                }
            }
        }
    }
    
    func createLock() {
        Log("WebDAVBackupInteractor - creating lock", module: .interactor)
        guard !shouldStop else {
            stop()
            Log("WebDAVBackupInteractor - stopping lock creation", module: .interactor)
            return
        }
        guard let currentSyncTimestamp = webDAVStateInteractor.currentSyncTimestamp,
              let encoded = mainRepository.webDAVEncodeLock(
                timestamp: currentSyncTimestamp,
                deviceId: mainRepository.deviceID ?? .init()
              ) else {
            Log("WebDAVBackupInteractor - error. No Last Sync object saved", module: .interactor, severity: .error)
            webDAVStateInteractor.syncError(.notConfigured)
            return
        }
        
        Log("WebDAVBackupInteractor - writing lock", module: .interactor)
        
        mainRepository.webDAVWriteLock(fileContents: encoded) { [weak self] result in
            switch result {
            case .success:
                Log("WebDAVBackupInteractor - lock written successfuly. Fetching Vault", module: .interactor)
                self?.fetchVault()
            case .failure(let error):
                Log("WebDAVBackupInteractor - error while writing lock: \(error)", module: .interactor, severity: .error)
                self?.commonErrorHandler(error)
            }
        }
    }
    
    func fetchVault() {
        Log("WebDAVBackupInteractor - fetching Vault", module: .interactor)
        guard !shouldStop else {
            Log("WebDAVBackupInteractor - stopping Vault fetch", module: .interactor)
            stop()
            return
        }
        let allowsAnyDeviceId = ignoreDeviceId || paymentStatusInteractor.entitlements.multiDeviceSync
        mainRepository.webDAVGetVault { [weak self] result in
            switch result {
            case .success(let vaultData):
                if self?.overwriteVault == true { // e.g. after Master Password change
                    self?.overwriteVault = false
                    self?.prepareForExport()
                    return
                }
                Log("WebDAVBackupInteractor - Vault fetched. Parsing", module: .interactor)
                self?.backupImportInteractor.parseContents(of: vaultData, decryptItemsIfPossible: true, allowsAnyDeviceId: allowsAnyDeviceId, completion: { [weak self] parseResult in
                    switch parseResult {
                    case .success(let parsedVault):
                        switch parsedVault {
                        case .decrypted(let items, let tags, let deleted, _, _, _, _):
                            Log("WebDAVBackupInteractor - Vault parsed correctly. Syncing with local database", module: .interactor)
                            self?.syncInteractor.syncAndApplyChanges(from: items, externalTags: tags, externalDeleted: deleted)
                            Log("WebDAVBackupInteractor - preparing for Vault export", module: .interactor)
                            self?.prepareForExport()
                        case .needsPassword:
                            Log("WebDAVBackupInteractor - can't decrypt Vault. Aborting", module: .interactor, severity: .error)
                            self?.webDAVStateInteractor.syncError(.notConfigured)
                        }
                    case .failure(let parseError):
                        switch parseError {
                        case .corruptedFile(let error):
                            Log("WebDAVBackupInteractor - error, Vault file corrupted: \(error)", module: .interactor, severity: .error)
                            self?.prepareForExport()
                        case .schemaNotSupported(let schemeVersion):
                            Log("WebDAVBackupInteractor - error, schema not supported: version \(schemeVersion)", module: .interactor, severity: .error)
                            self?.webDAVStateInteractor.syncError(.schemaNotSupported(schemeVersion))
                        case .nothingToImport:
                            Log("WebDAVBackupInteractor - nothing to import", module: .interactor)
                            if self?.mainRepository.webDAVHasLocalChanges == true {
                                Log("WebDAVBackupInteractor - there are local changes. Preparing for export", module: .interactor)
                                self?.prepareForExport()
                            } else {
                                Log("WebDAVBackupInteractor - no local changes. Finishing", module: .interactor)
                                self?.success()
                            }
                        case .errorDecrypting:
                            Log("WebDAVBackupInteractor - error while parsing Vault. Decryption error", module: .interactor, severity: .error)
                            self?.webDAVStateInteractor.syncError(.notConfigured)
                        case .otherDeviceId:
                            Log("WebDAVBackupInteractor - error while parsing Vault. Other device id error", module: .interactor, severity: .error)
                            self?.webDAVStateInteractor.syncError(.limitDevicesReached)
                        case .passwordChanged:
                            Log("WebDAVBackupInteractor - error while parsing Vault - possibly password changed", module: .interactor)
                            self?.webDAVStateInteractor.syncError(.passwordChanged)
                        }
                    }
                })
            case .failure(let error):
                switch error {
                case .unauthorized:
                    Log("WebDAVBackupInteractor - fetching Vault error: unauthorized", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.unauthorized)
                case .forbidden:
                    Log("WebDAVBackupInteractor - fetching Vault error: forbidden", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.forbidden)
                case .syncErrorTryingAgain:
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - fetching Vault error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry()
                    } else {
                        Log("WebDAVBackupInteractor - fetching Vault error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.syncError(nil))
                    }
                case .notFound:
                    Log("WebDAVBackupInteractor - no Vault found. Creating", module: .interactor)
                    self?.prepareForExport()
                case .syncError(let error):
                    Log("WebDAVBackupInteractor - fetching Vault error: sync error \(error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.syncError(error.localizedDescription))
                case .networkError(let error):
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - fetching Vault network error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry(reason: error.localizedDescription, time: self?.noInternetRetry)
                    } else {
                        Log("WebDAVBackupInteractor - fetching Vault network error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.networkError(error.localizedDescription))
                    }
                case .serverError(let error):
                    if self?.webDAVStateInteractor.canRetry == true {
                        Log("WebDAVBackupInteractor - fetching Vault server error, retrying", module: .interactor, severity: .error)
                        self?.setupRetry(reason: error.localizedDescription)
                    } else {
                        Log("WebDAVBackupInteractor - fetching Vault server error, final", module: .interactor, severity: .error)
                        self?.webDAVStateInteractor.syncError(.serverError(error.localizedDescription))
                    }
                case .urlError(let error):
                    Log("WebDAVBackupInteractor - fetching Vault error: url error: \(error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.urlError(error.localizedDescription))
                case .sslError:
                    Log("WebDAVBackupInteractor - fetching Vault error: SSL error)", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.sslError)
                case .methodNotAllowed:
                    Log("WebDAVBackupInteractor - fetching Vault error: method not allowed", module: .interactor, severity: .error)
                    self?.webDAVStateInteractor.syncError(.methodNotAllowed)
                }
            }
        }
    }
    
    func prepareForExport() {
        Log("WebDAVBackupInteractor - preparing for export", module: .interactor)
        exportInteractor.prepareItemsForExport(encrypt: true, exportIfEmpty: true, includeDeletedItems: true, completion: { [weak self] exportResult in
            switch exportResult {
            case .success(let vaultForExport):
                Log("WebDAVBackupInteractor - vault for export ready", module: .interactor)
                self?.writeVault(vaultForExport.0)
            case .failure(let exportError):
                Log("WebDAVBackupInteractor - error while preparing vault for export: \(exportError)", module: .interactor, severity: .error)
                self?.webDAVStateInteractor.syncError(.syncError(exportError.localizedDescription))
            }
        })
        
        guard mainRepository.webDAVWriteDecryptedCopy else { return }
        
        Log("WebDAVBackupInteractor - preparing decrypted copy for debug", module: .interactor)
        
        exportInteractor.prepareItemsForExport(encrypt: false, exportIfEmpty: true, includeDeletedItems: true, completion: { [weak self] exportResult in
            switch exportResult {
            case .success(let vaultForExport):
                Log("WebDAVBackupInteractor - decrypted vault for export ready", module: .interactor)
                self?.mainRepository.webDAVWriteDecryptedVault(fileContents: vaultForExport.0) { result in
                    switch result {
                    case .success:
                        Log("WebDAVBackupInteractor - decrypted vault written successfuly", module: .interactor)
                    case .failure(let error):
                        Log("WebDAVBackupInteractor - error while writing decrypted vault: \(error)", module: .interactor, severity: .error)
                    }
                }
            case .failure(let exportError):
                Log("WebDAVBackupInteractor - error while preparing decrypted vault for export: \(exportError)", module: .interactor, severity: .error)
            }
        })
    }
    
    func writeVault(_ vault: Data) {
        Log("WebDAVBackupInteractor - writing vault", module: .interactor)
        guard !shouldStop else {
            stop()
            Log("WebDAVBackupInteractor - writing vault - stopping", module: .interactor)
            return
        }
        mainRepository.webDAVWriteVault(fileContents: vault) { [weak self] result in
            switch result {
            case .success:
                Log("WebDAVBackupInteractor - vault written successfuly", module: .interactor)
                self?.moveVault()
            case .failure(let error):
                Log("WebDAVBackupInteractor - error while writing vault: \(error)", module: .interactor, severity: .error)
                self?.commonErrorHandler(error)
            }
        }
    }
    
    func moveVault() {
        Log("WebDAVBackupInteractor - moving vault", module: .interactor)
        guard !shouldStop else {
            stop()
            Log("WebDAVBackupInteractor - stopping moving vault", module: .interactor)
            return
        }
        mainRepository.webDAVMove { [weak self] result in
            switch result {
            case .success:
                Log("WebDAVBackupInteractor - vault moved successfuly", module: .interactor)
                self?.writeIndex()
            case .failure(let error):
                Log("WebDAVBackupInteractor - error while moving vault: \(error)", module: .interactor, severity: .error)
                self?.commonErrorHandler(error)
            }
        }
    }
    
    func writeIndex() {
        Log("WebDAVBackupInteractor - writing index", module: .interactor)
        guard let index = prepareIndex(), let data = mainRepository.webDAVEncodeIndex(index) else {
            webDAVStateInteractor.syncError(.notConfigured)
            Log("WebDAVBackupInteractor - error. No index preppared or encoding error", module: .interactor, severity: .error)
            return
        }
        mainRepository.webDAVWriteIndex(fileContents: data) { [weak self] result in
            switch result {
            case .success:
                Log("WebDAVBackupInteractor - index written successfuly", module: .interactor)
                self?.webDAVStateInteractor.markIndexAsWritten()
                self?.removeLock()
            case .failure(let error):
                Log("WebDAVBackupInteractor - error while writing index: \(error)", module: .interactor, severity: .error)
                self?.commonErrorHandler(error)
            }
        }
    }
    
    func removeLock() {
        Log("WebDAVBackupInteractor - removing lock", module: .interactor)
        mainRepository.webDAVDeleteLock { [weak self] result in
            switch result {
            case .success:
                Log("WebDAVBackupInteractor - lock removed successfuly", module: .interactor)
                self?.success()
            case .failure(let error):
                Log("WebDAVBackupInteractor - error while removing lock: \(error)", module: .interactor, severity: .error)
                self?.commonErrorHandler(error)
            }
        }
    }
}

private extension WebDAVBackupInteractor {
    func commonErrorHandler(_ error: BackupWebDAVSyncError) {
        Log("WebDAVBackupInteractor - handling common error: \(error)", module: .interactor, severity: .error)
        switch error {
        case .unauthorized:
            webDAVStateInteractor.syncError(.unauthorized)
        case .forbidden:
            webDAVStateInteractor.syncError(.forbidden)
        case .syncErrorTryingAgain:
            if webDAVStateInteractor.canRetry {
                Log("WebDAVBackupInteractor - sync error, retrying", module: .interactor, severity: .error)
                setupRetry()
            } else {
                Log("WebDAVBackupInteractor - sync error, final", module: .interactor, severity: .error)
                webDAVStateInteractor.syncError(.syncError(nil))
            }
        case .notFound:
            webDAVStateInteractor.syncError(.notConfigured)
        case .syncError(let error):
            webDAVStateInteractor.syncError(.syncError(error.localizedDescription))
        case .networkError(let error):
            if webDAVStateInteractor.canRetry {
                Log("WebDAVBackupInteractor - network error, retrying", module: .interactor, severity: .error)
                setupRetry(reason: error.localizedDescription, time: noInternetRetry)
            } else {
                Log("WebDAVBackupInteractor - network error, final", module: .interactor, severity: .error)
                webDAVStateInteractor.syncError(.networkError(error.localizedDescription))
            }
        case .serverError(let error):
            if webDAVStateInteractor.canRetry {
                Log("WebDAVBackupInteractor - server error, retrying", module: .interactor, severity: .error)
                setupRetry(reason: error.localizedDescription)
            } else {
                Log("WebDAVBackupInteractor - server error, final", module: .interactor, severity: .error)
                webDAVStateInteractor.syncError(.serverError(error.localizedDescription))
            }
        case .urlError(let error):
            webDAVStateInteractor.syncError(.urlError(error.localizedDescription))
        case .sslError:
            webDAVStateInteractor.syncError(.sslError)
        case .methodNotAllowed:
            webDAVStateInteractor.syncError(.methodNotAllowed)
        }
    }
    
    func success() {
        Log("WebDAVBackupInteractor - success", module: .interactor)
        webDAVStateInteractor.syncSucceded()
        stop()
        
        if syncAgain {
            Log("WebDAVBackupInteractor - syncing again", module: .interactor)
            syncAgain = false
            sync()
        } else {
            Log("WebDAVBackupInteractor - sync finished", module: .interactor)
            mainRepository.webDAVClearHasLocalChanges()
        }
    }
    
    func stop() {
        Log("WebDAVBackupInteractor - stopping", module: .interactor)
        fetchedIndex = nil
        shouldStop = false
    }
    
    func prepareIndex() -> WebDAVIndex? {
        Log("WebDAVBackupInteractor - preparing index", module: .interactor)
        
        guard let deviceId = mainRepository.deviceID else {
            Log("WebDAVBackupInteractor - error. No deviceID", module: .interactor, severity: .error)
            return nil
        }
        
        guard let vault = mainRepository.selectedVault,
              let seedHash = mainRepository.webDAVSeedHash else {
            webDAVStateInteractor.syncError(.syncError(nil))
            Log("WebDAVBackupInteractor - error. No vault or seed hash", module: .interactor, severity: .error)
            return nil
        }
        
        let updatedAt = webDAVStateInteractor.currentSyncTimestamp ?? Date().exportTimestamp
        let deviceName = mainRepository.deviceName
        
        let entry = WebDAVIndexEntry(
            seedHashHex: seedHash,
            vaultId: vault.vaultID.uuidString.lowercased(),
            vaultCreatedAt: vault.createdAt.exportTimestamp,
            vaultUpdatedAt: updatedAt,
            deviceName: deviceName,
            deviceId: deviceId
        )
        let result: WebDAVIndex
        if let fetchedIndex {
            var index = fetchedIndex.backups
            if let matchingVaultIndex = fetchedIndex.firstIndex(for: vault.vaultID, seedHash: seedHash) {
                var matchingVault = index[matchingVaultIndex]
                matchingVault.vaultUpdatedAt = updatedAt
                index[matchingVaultIndex] = matchingVault
            } else {
                index.append(entry)
            }
            result = WebDAVIndex(backups: index)
        } else {
            result = WebDAVIndex(backups: [entry])
        }
        return result
    }
    
    func setupRetry(reason: String? = nil, time: Int? = nil) {
        Log("WebDAVBackupInteractor - setup retry. Time: \(time ?? Config.webDAVLockFileTime)", module: .interactor)
        webDAVStateInteractor.syncRetry(reason)
        retry(time)
    }
    
    func retry(_ time: Int? = nil) {
        DispatchQueue.main.async {
            self.timerInteractor.setTickEverySecond(seconds: time ?? Config.webDAVLockFileTime)
            guard !self.timerInteractor.isRunning else {
                Log("WebDAVBackupInteractor - timer already running. Aborting", module: .interactor)
                return
            }
            Log("WebDAVBackupInteractor - setting up timer", module: .interactor)
            self.timerInteractor.start()
        }
    }
    
    func resume() {
        Log("WebDAVBackupInteractor - resuming", module: .interactor)
        timerInteractor.pause()
        
        guard webDAVStateInteractor.canResyncAutomatically else { return }
        sync(isRetry: true)
    }
}
