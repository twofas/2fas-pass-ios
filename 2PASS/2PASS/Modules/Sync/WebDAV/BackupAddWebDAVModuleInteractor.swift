// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Backup

enum BackupAddWebDAVModuleInteractorStatus {
    case idle
    case syncing
    case unauthorized
    case forbidden
    case sslError
    case methodNotAllowed
    case notConfigured
    case urlError(String)
    case syncError(String?)
    case retrying(String?)
    case newerVersionNeeded
    case networkError(String)
    case serverError(String)
    case synced
    case limitDevicesReached
    case passwordChanged
}

protocol BackupAddWebDAVModuleInteracting: AnyObject {
    var currentStatus: BackupAddWebDAVModuleInteractorStatus { get }
    var statusChanged: ((BackupAddWebDAVModuleInteractorStatus) -> Void)? { get set }
    
    var isSyncCloudEnabled: Bool { get }
    var isConnected: Bool { get }
    var isConnecting: Bool { get }
    func disableSyncCloud()
    
    var savedConfiguration: BackupWebDAVConfig? { get }
    func disconnect()
    
    func isSecureURL(_ url: URL) -> Bool
    func normalizeURL(_ str: String) -> URL?
    func connect(url: String, normalizedURL: URL, allowTLSOff: Bool, login: String?, password: String?)
}

final class BackupAddWebDAVModuleInteractor {
    private let webDAVBackupInteractor: WebDAVBackupInteracting
    private let webDAVStateInteractor: WebDAVStateInteracting
    private let cloudSyncInteractor: CloudSyncInteracting
    private let uriInteractor: URIInteracting
    private let notificationCenter: NotificationCenter
        
    var statusChanged: ((BackupAddWebDAVModuleInteractorStatus) -> Void)?
    var currentStatus: BackupAddWebDAVModuleInteractorStatus {
        stateToStatus(webDAVStateInteractor.state)
    }

    init(webDAVBackupInteractor: WebDAVBackupInteracting, webDAVStateInteractor: WebDAVStateInteracting, uriInteractor: URIInteracting, cloudSyncInteractor: CloudSyncInteracting) {
        self.webDAVBackupInteractor = webDAVBackupInteractor
        self.webDAVStateInteractor = webDAVStateInteractor
        self.cloudSyncInteractor = cloudSyncInteractor
        self.uriInteractor = uriInteractor
        self.notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(stateChanged), name: .webDAVStateChange, object: nil)
    }
}

extension BackupAddWebDAVModuleInteractor: BackupAddWebDAVModuleInteracting {
    
    func isSecureURL(_ url: URL) -> Bool {
        uriInteractor.isSecureURL(url)
    }
    
    var isSyncCloudEnabled: Bool {
        if case .enabled = cloudSyncInteractor.currentState {
            return true
        } else {
            return false
        }
    }
    
    func disableSyncCloud() {
        switch cloudSyncInteractor.currentState {
        case .enabled(let sync):
            switch sync {
            case .synced: cloudSyncInteractor.disable()
            default: break
            }
        default: break
        }
    }
    
    var savedConfiguration: BackupWebDAVConfig? {
        webDAVStateInteractor.getConfig()
    }
    
    var isConnected: Bool {
        webDAVStateInteractor.isConnected
    }
    
    var isConnecting: Bool {
        webDAVStateInteractor.isSyncing
    }
    
    func disconnect() {
        webDAVBackupInteractor.disconnect()
        webDAVStateInteractor.clearConfig()
    }
        
    func normalizeURL(_ str: String) -> URL? {
        uriInteractor.normalizeURL(str, options: .trailingSlash)
    }
    
    func connect(url: String, normalizedURL: URL, allowTLSOff: Bool, login: String?, password: String?) {
        webDAVStateInteractor.setConfig(baseURL: url, normalizedBaseURL: normalizedURL, allowTLSOff: allowTLSOff, login: login, password: password)
        webDAVBackupInteractor.sync()
    }
}

private extension BackupAddWebDAVModuleInteractor {
    @objc
    func stateChanged(notification: Notification) {
        guard let state = notification.userInfo?[Notification.webDAVState] as? WebDAVState else {
            return
        }
        statusChanged?(stateToStatus(state))
    }
    
    func stateToStatus(_ state: WebDAVState) -> BackupAddWebDAVModuleInteractorStatus {
        switch state {
        case .idle: return .idle
        case .syncing: return .syncing
        case .error(let syncError):
            switch syncError {
            case .unauthorized: return .unauthorized
            case .forbidden: return .forbidden
            case .newerVersionNeeded: return .newerVersionNeeded
            case .notConfigured: return .notConfigured
            case .syncError(let string): return .syncError(string)
            case .networkError(let string): return .networkError(string)
            case .serverError(let string): return .serverError(string)
            case .urlError(let string): return .urlError(string)
            case .sslError: return .sslError
            case .methodNotAllowed: return .methodNotAllowed
            case .limitDevicesReached: return .limitDevicesReached
            case .passwordChanged: return .passwordChanged
            }
        case .retry(let string): return .retrying(string)
        case .synced: return .synced
        }
    }
}
