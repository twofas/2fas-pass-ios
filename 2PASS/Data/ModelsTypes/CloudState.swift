// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum CloudState: Equatable {
    public enum NotAvailableReason: Equatable {
        case overQuota
        case disabledByUser
        case error(error: NSError?)
        case useriCloudProblem
        case other
        case noAccount
        case restricted
        case schemaNotSupported(Int)
        case incorrectEncryption
    }
    
    public enum OutOfSyncReason: Equatable {
        case schemaNotSupported(Int)
    }
    
    public enum Sync: Equatable {
        case syncing
        case synced
        case outOfSync(OutOfSyncReason)
    }
    
    case unknown
    case disabledNotAvailable(reason: NotAvailableReason)
    case disabledAvailable
    case enabled(sync: Sync)
    
    public var hasError: Bool {
        switch self {
        case .enabled(sync: .outOfSync):
            true
        case .disabledNotAvailable(let reason):
            switch reason {
            case .overQuota,
                    .disabledByUser,
                    .error,
                    .other,
                    .useriCloudProblem,
                    .schemaNotSupported,
                    .incorrectEncryption: true
            default: false
            }
        default: false
        }
    }
    
    public var isSyncing: Bool {
        switch self {
        case .enabled(.syncing): true
        default: false
        }
    }
    
    public var isSynced: Bool {
        switch self {
        case .enabled(.synced): true
        default: false
        }
    }
    
    public var isSchemeNotSupported: Bool {
        switch self {
        case .enabled(sync: .outOfSync(.schemaNotSupported)),
             .disabledNotAvailable(reason: .schemaNotSupported):
            return true
        default:
            return false
        }
    }
}
