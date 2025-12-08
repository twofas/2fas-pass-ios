// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

protocol CloudHandlerType: AnyObject {
    var userToggledState: UserToggledState? { get set }
    var currentState: CloudCurrentState { get }
    var isConnected: Bool { get }
    
    func setVaultID(vaultID: VaultID)
    func checkState()
    func synchronize()
    func enable()
    func disable(notify: Bool)
    func clearBackup()
    func resetStateBeforeSync()
    
    func resetBeforeMigration()
}

final class CloudHandler: CloudHandlerType {
    private let cloudAvailability: CloudAvailability
    private let syncHandler: SyncHandler
    private let clearHandler: ClearHandler
    private let mergeHandler: MergeHandler
    private let cacheHandler: CacheHandler
    
    private var vaultID: VaultID?
    
    private var isClearing = false
    
    private var shouldResetState = false
    private var isEnabling = false
    
    
    private(set) var currentState: CloudCurrentState = .unknown {
        didSet {
            guard oldValue != currentState else { return }
            guard !isClearing else { return }
            
            switch currentState {
            case .enabled(sync: .syncing): break
            default: isEnabling = false
            }
            
            Log("Cloud Handler - state change \(currentState)", module: .cloudSync)
            NotificationCenter.default.post(name: .cloudStateChanged, object: nil)
        }
    }
    
    var userToggledState: UserToggledState?
    
    init(
        cloudAvailability: CloudAvailability,
        syncHandler: SyncHandler,
        mergeHandler: MergeHandler,
        cacheHandler: CacheHandler
    ) {
        self.cloudAvailability = cloudAvailability
        self.syncHandler = syncHandler
        self.mergeHandler = mergeHandler
        self.cacheHandler = cacheHandler
        clearHandler = ClearHandler()

        mergeHandler.schemaNotSupported = { [weak self] schemaVersion in
            self?.schemaNotSupported(schemaVersion)
        }
        mergeHandler.incorrectEncryption = { [weak self] in self?.incorrectEncryption() }
        mergeHandler.syncNotAllowed = { [weak self] in self?.syncNotAllowed() }
        
        cloudAvailability.availabilityCheckResult = { [weak self] resultStatus in
            self?.availabilityCheckResult(resultStatus)
        }
        
        syncHandler.startedSync = { [weak self] in self?.startedSync() }
        syncHandler.finishedSync = { [weak self] in self?.finishedSync() }
        syncHandler.otherError = { [weak self] error in self?.otherError(error) }
        syncHandler.quotaExceeded = { [weak self] in self?.quotaError() }
        syncHandler.userDisabledCloud = { [weak self] in self?.disabledByUser() }
        syncHandler.useriCloudProblem = { [weak self] in self?.useriCloudProblem() }
        syncHandler.refreshLocalData = {
            NotificationCenter.default.post(name: .cloudRefreshLocalData, object: nil)
        }
        
        clearHandler.didClear = { [weak self] in self?.didClear() }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(setPasswordWasChanged),
            name: .passwordWasChanged,
            object: nil
        )
    }
    
    func setVaultID(vaultID: VaultID) {
        Log("Cloud Handler - setting VaultID", module: .cloudSync)
        self.vaultID = vaultID
    }
    
    func checkState() {
        guard !isClearing else { return }
        Log("Cloud Handler - checking state", module: .cloudSync)
        cloudAvailability.checkAvailability()
    }
    
    func synchronize() {
        guard !isClearing else { return }
        
        Log("Cloud Handler -  Got Synchronize action", module: .cloudSync)
        if shouldResetState {
            Log("Cloud Handler - Reseting state", module: .cloudSync)
            shouldResetState = false
            resetBeforeMigration()
        }
        switch currentState {
        case .unknown:
            Log("Cloud Handler - unknown state on synchronize", module: .cloudSync)
            checkState()
        case .enabledNotAvailable:
            Log("Cloud Handler - enabled but not available state on synchronize", module: .cloudSync)
            sync()
        case .enabled:
            Log("Cloud Handler -  is enabled - syncing", module: .cloudSync)
            sync()
        case .disabled:
            Log("Cloud Handler -  Can't synchronize if cloud is disabled", module: .cloudSync)
        }
    }
    
    func enable() {
        guard !isClearing else { return }

        isEnabling = true
        
        Log("Cloud Handler - Got Enable action", module: .cloudSync)
        switch currentState {
        case .enabled, .enabledNotAvailable:
            Log("Cloud Handler - Can't enable again!", module: .cloudSync)
        case .disabled:
            Log("Cloud Handler - enable and state is disabledAvailable - enabling!", module: .cloudSync)
            setEnabled()
            userToggledState?(true)
            sync()
        case .unknown:
            Log("Cloud Handler - Can't enable - state unknown", module: .cloudSync)
        }
    }
    
    func disable(notify: Bool = true) {
        Log("Cloud Handler - Got Disable action", module: .cloudSync)
        switch currentState {
        case .enabled, .unknown, .enabledNotAvailable:
            Log("Cloud Handler - is enabled - disabling", module: .cloudSync)
            setDisabled()
            clearCache()
            if notify {
                userToggledState?(false)
            }
            currentState = .disabled
        case .disabled:
            Log("Cloud Handler - Can't disable again!", module: .cloudSync)
        }
    }
    
    func clearBackup() {
        isClearing = true
        if isSynced {
            clearBackupForSyncedState()
        }
    }
    
    var isConnected: Bool {
        switch currentState {
        case .enabled: return true
        default: return false
        }
    }
    
    func resetStateBeforeSync() {
        shouldResetState = true
    }
    
    var isSynced: Bool {
        switch currentState {
        case .enabled(let sync):
            switch sync {
            case .synced: return true
            default: return false
            }
        default: return false
        }
    }
    
    // MARK: - Private
    func resetBeforeMigration() {
        Log("Cloud Handler - resetBeforeMigration", module: .cloudSync)
        syncHandler.firstStart()
    }
    
    private func availabilityCheckResult(_ resultStatus: CloudAvailabilityStatus) {
        Log("Cloud Handler - availabilityCheckResult \(resultStatus)", module: .cloudSync)
        switch resultStatus {
        case .available:
            if isEnabled {
                sync()
            } else {
                currentState = .disabled
            }
        case .accountChanged:
            if isEnabled {
                Log("Cloud Handler - account changed - clearing all, first start", module: .cloudSync)
                clearCache()
                syncHandler.firstStart()
                sync()
            } else {
                currentState = .disabled
            }
        case .error(let error):
            otherError(error)
        case .noAccount:
            clearCache()
            currentState = .enabledNotAvailable(reason: .noAccount)
        case .restricted:
            clearCache()
            currentState = .enabledNotAvailable(reason: .restricted)
        case .notAvailable:
            clearCache()
            currentState = .enabledNotAvailable(reason: .other)
        }
    }
    
    private func sync() {
        Log("Cloud Handler - Sync", module: .cloudSync)
        guard let vaultID else {
            Log("Cloud Handler - VaultID not set!", module: .cloudSync, severity: .error)
            return
        }
        syncHandler.synchronize(zoneID: .from(vaultID: vaultID))
    }
    
    private func clearCache() {
        Log("Cloud Handler - clear cache", module: .cloudSync)
        cloudAvailability.clear()
        syncHandler.clearCacheAndDisable()
    }
    
    // MARK: -
    
    private func setEnabled() {
        Log("Cloud Handler - Set Enabled", module: .cloudSync)
        ConstStorage.cloudEnabled = true
        syncHandler.firstStart()
    }
    
    private func setDisabled() {
        Log("Cloud Handler - Set Disabled", module: .cloudSync)
        ConstStorage.cloudEnabled = false
    }
    
    private var isEnabled: Bool { ConstStorage.cloudEnabled }
    
    // MARK: - Clearing
    
    private func didClear() {
        Log("Cloud Handler - didClear", module: .cloudSync)
        isClearing = false
    }
    
    private func clearBackupForSyncedState() {
        Log("Cloud Handler - clearBackupForSyncedState", module: .cloudSync)
        let recordIDs = cacheHandler.listAllItemsRecordIDs()
        disable(notify: false)
        clearHandler.clear(recordIDs: recordIDs)
    }
    
    // MARK: -
    
    @objc
    private func setPasswordWasChanged() {
        guard currentState == .enabled(sync: .syncing) || currentState == .enabled(sync: .synced) else {
            return
        }
        Log("Cloud Handler - Setting Password was changed", module: .cloudSync)
        ConstStorage.passwordWasChanged = true
    }
    
    private func startedSync() {
        Log("Cloud Handler - Started Sync", module: .cloudSync)
        currentState = .enabled(sync: .syncing)
    }
    
    private func finishedSync() {
        Log("Cloud Handler - Finished Sync", module: .cloudSync)
        currentState = .enabled(sync: .synced)
        ConstStorage.passwordWasChanged = false
        NotificationCenter.default.post(name: .cloudDidSync, object: nil)
        
        if isClearing {
            clearBackup()
        }
    }
    
    private func quotaError() {
        Log("Cloud Handler - Quota Error", module: .cloudSync)
        clearCache()
        currentState = .enabledNotAvailable(reason: .overQuota)
    }
    
    private func disabledByUser() {
        Log("Cloud Handler - Disabled by User", module: .cloudSync)
        clearCache()
        currentState = .enabledNotAvailable(reason: .disabledByUser)
    }
    
    private func useriCloudProblem() {
        Log("Cloud Handler - User has iCloud problem", module: .cloudSync)
        clearCache()
        currentState = .enabledNotAvailable(reason: .useriCloudProblem)
    }
    
    private func otherError(_ error: NSError?) {
        Log("Cloud Handler - Other Error \(String(describing: error))", module: .cloudSync)
        clearCache()
        currentState = .enabledNotAvailable(reason: .error(error: error))
    }
    
    private func schemaNotSupported(_ schemaVersion: Int) {
        Log("Cloud Handler - schema not supported (v\(schemaVersion))", module: .cloudSync)
        
        currentState = .enabledNotAvailable(reason: .schemaNotSupported(schemaVersion))
        clearCache()
    }
    
    private func incorrectEncryption() {
        Log("Cloud Handler - newer version of cloud", module: .cloudSync)
        clearCache()
        currentState = .enabledNotAvailable(reason: .incorrectEncryption)
    }
    
    private func syncNotAllowed() {
        Log("Cloud Handler - sync not allowed", module: .cloudSync)
        setDisabled()
        clearCache()
        currentState = .disabled
        NotificationCenter.default.post(name: .presentSyncPremiumNeededScreen, object: nil)
    }
    
    // MARK: -
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
