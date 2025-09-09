// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Backup
import Common

public extension Notification.Name {
    static let webDAVStateChange = Notification.Name("webDAVStateChange")
    static let settingsSyncStateChanged = Notification.Name("settingsSyncStateChanged")
}

public extension Notification {
    static let webDAVState = "webDAVState"
}

public protocol WebDAVStateInteracting: AnyObject {
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    var lastSyncTimestamp: Int? { get }
    var isConnected: Bool { get }
    var state: WebDAVState { get }
    var canResyncAutomatically: Bool { get }
    var currentSyncTimestamp: Int? { get }
    
    var canRetry: Bool { get }
    
    func markIndexAsWritten()
    func startSync(isRetry: Bool)
    func syncError(_ error: WebDAVState.SyncError)
    func syncSucceded()
    func syncRetry(_ reason: String?)
    func disconnect()
    
    func getConfig() -> BackupWebDAVConfig?

    func setConfig(baseURL: String, normalizedBaseURL: URL, allowTLSOff: Bool, login: String?, password: String?)
    func clearConfig()

    var awaitsVaultOverrideAfterPasswordChange: Bool { get }
    func setAwaitsVaultOverrideAfterPasswordChange()
    func clearAwaitsVaultOverrideAfterPasswordChange()
}

final class WebDAVStateInteractor {
    private let mainRepository: MainRepository
    private let notificationCenter: NotificationCenter
    
    private let maxRetryConnected = 2
    private let maxRetryDisconnected = 1
    private var retryLimit = 0
    
    private(set) var currentSyncTimestamp: Int?
    private var wasIndexWritten = false
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
        self.notificationCenter = NotificationCenter.default
        
        notificationCenter.post(
            name: .webDAVStateChange,
            object: nil,
            userInfo: [Notification.webDAVState: WebDAVState.idle]
        )
    }
}

extension WebDAVStateInteractor {
    var isSyncing: Bool {
        switch state {
        case .idle, .error, .retry, .synced: false
        case .syncing: true
        }
    }
    
    var lastSyncTimestamp: Int? {
        guard let timestamp = mainRepository.webDAVLastSync?.timestamp else {
            return nil
        }
        return timestamp
    }
    
    var lastSyncDate: Date? {
        guard let lastSyncTimestamp else {
            return nil
        }
        return Date(exportTimestamp: lastSyncTimestamp)
    }
    
    var isConnected: Bool {
        mainRepository.webDAVIsConnected
    }
    
    var state: WebDAVState {
        mainRepository.webDAVState
    }
    
    func getConfig() -> BackupWebDAVConfig? {
        mainRepository.webDAVSavedConfig
    }
    
    var awaitsVaultOverrideAfterPasswordChange: Bool {
        mainRepository.webDAVAwaitsVaultOverrideAfterPasswordChange
    }
    
    func setAwaitsVaultOverrideAfterPasswordChange() {
        mainRepository.setWebDAVAwaitsVaultOverrideAfterPasswordChange(true)
    }
    
    func clearAwaitsVaultOverrideAfterPasswordChange() {
        mainRepository.setWebDAVAwaitsVaultOverrideAfterPasswordChange(false)
    }
    
    func setConfig(baseURL: String, normalizedBaseURL: URL, allowTLSOff: Bool, login: String?, password: String?) {
        Log("WebDAVStateInteractor - setting config", module: .interactor)
        guard let vid = mainRepository.selectedVault?.vaultID else {
            Log("WebDAVStateInteractor - error while getting current VaultID", module: .interactor, severity: .error)
            return
        }

        let current = getConfig()
        guard current?.baseURL != baseURL
                || current?.normalizedURL != normalizedBaseURL
                || current?.allowTLSOff != allowTLSOff
                || current?.login != login
                || current?.password != password
        else {
            return
        }
        mainRepository.webDAVSaveSavedConfig(
            .init(
                baseURL: baseURL,
                normalizedURL: normalizedBaseURL,
                lockTime: Config.webDAVLockFileTime,
                allowTLSOff: allowTLSOff,
                vid: vid.uuidString,
                login: login,
                password: password
            )
        )
        mainRepository.webDAVSetIsConnected(false)
    }
}

extension WebDAVStateInteractor: WebDAVStateInteracting {
    var canResyncAutomatically: Bool {
        switch mainRepository.webDAVState {
        case .idle: return true
        case .syncing: return false
        case .error(let syncError):
            switch syncError {
            case .unauthorized, .forbidden, .newerVersionNeeded, .schemaNotSupported, .notConfigured, .urlError, .sslError, .methodNotAllowed, .limitDevicesReached, .passwordChanged: return false
            case .syncError, .networkError, .serverError: return true
            }
        case .retry: return true
        case .synced: return true
        }
    }
    
    var lastSync: WebDAVLock? {
        mainRepository.webDAVLastSync
    }
    
    func markIndexAsWritten() {
        wasIndexWritten = true
    }
    
    func startSync(isRetry: Bool) {
        currentSyncTimestamp = mainRepository.currentDate.exportTimestamp
        wasIndexWritten = false
        
        if isRetry == false {
            retryLimit = 0
        }
        
        Log("WebDAVStateInteractor - starting sync. Timestamp: \(currentSyncTimestamp ?? -1)", module: .interactor)
        mainRepository.webDAVSetState(.syncing)
        notificationCenter.post(
            name: .webDAVStateChange,
            object: nil,
            userInfo: [Notification.webDAVState: WebDAVState.syncing]
        )
    }
    
    func syncError(_ error: WebDAVState.SyncError) {
        Log("WebDAVStateInteractor - sync error: \(error)", module: .interactor, severity: .error)
        mainRepository.webDAVSetState(.error(error))
        clearFlags()

        notificationCenter.post(
            name: .webDAVStateChange,
            object: nil,
            userInfo: [Notification.webDAVState: WebDAVState.error(error)]
        )
    }
    
    func syncSucceded() {
        Log("WebDAVStateInteractor - sync succeded", module: .interactor)
        guard let currentSyncTimestamp else {
            Log("WebDAVStateInteractor - error getting currentSyncTimestamp", module: .interactor, severity: .error)
            return
        }
        if wasIndexWritten {
            Log("WebDAVStateInteractor - saving timestamp: \(currentSyncTimestamp)", module: .interactor)
            mainRepository.webDAVSetLastSync(
                .init(deviceId: mainRepository.deviceID ?? .init(), timestamp: currentSyncTimestamp)
            )
        }
        clearFlags()
        mainRepository.webDAVSetIsConnected(true)
        mainRepository.webDAVSetState(.synced)
        mainRepository.webDAVClearHasLocalChanges()
        notificationCenter.post(
            name: .webDAVStateChange,
            object: nil,
            userInfo: [Notification.webDAVState: WebDAVState.synced]
        )
    }
    
    func syncRetry(_ reason: String?) {
        Log("WebDAVStateInteractor - sync retry. Reason: \(reason ?? "-")", module: .interactor)
        mainRepository.webDAVSetState(.retry(reason))
        retryLimit += 1
        notificationCenter.post(
            name: .webDAVStateChange,
            object: nil,
            userInfo: [Notification.webDAVState: WebDAVState.retry]
        )
    }
    
    var canRetry: Bool {
        if mainRepository.webDAVIsConnected {
            return retryLimit < maxRetryConnected
        } else {
            return retryLimit < maxRetryDisconnected
        }
    }
    
    func disconnect() {
        Log("WebDAVStateInteractor - disconnecting", module: .interactor)
        mainRepository.webDAVClearIsConnected()
        mainRepository.webDAVClearState()
        mainRepository.webDAVClearLastSync()
        mainRepository.webDAVClearHasLocalChanges()
        clearFlags()
        notificationCenter.post(
            name: .webDAVStateChange,
            object: nil,
            userInfo: [Notification.webDAVState: WebDAVState.idle]
        )
    }
    
    func clearConfig() {
        mainRepository.webDAVClearConfig()
    }
    
    func clearFlags() {
        currentSyncTimestamp = nil
        wasIndexWritten = false
        retryLimit = 0
    }
}
