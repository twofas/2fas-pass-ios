// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public enum WebDAVState: Equatable, Codable {
    public enum SyncError: Error, Equatable, Codable {
        case unauthorized
        case forbidden
        case limitDevicesReached
        case methodNotAllowed
        case schemaNotSupported(Int)
        case notConfigured
        case passwordChanged
        case sslError
        case urlError(String)
        case syncError(String?)
        case networkError(String)
        case serverError(String)
    }
    case idle
    case syncing
    case error(SyncError)
    case retry(String?)
    case synced
    
    public var hasError: Bool {
        switch self {
        case .error, .retry: true
        default: false
        }
    }
    
    public var isSyncing: Bool {
        switch self {
        case .syncing, .retry: true
        default: false
        }
    }
    
    public var isSynced: Bool {
        self == .synced
    }
    
    public var isLimitDevicesReached: Bool {
        self == .error(.limitDevicesReached)
    }
    
    public var isSchemeNotSupported: Bool {
        switch self {
        case .error(.schemaNotSupported):
            return true
        default:
            return false
        }
    }
}
