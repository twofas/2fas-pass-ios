// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public typealias UserToggledState = (Bool) -> Void

public enum CloudCurrentState: Equatable {
    public enum NotAvailableReason: Equatable {
        case overQuota
        case disabledByUser
        case useriCloudProblem
        case error(error: NSError?)
        case other
        case noAccount
        case restricted
        case schemaNotSupported(Int)
        case incorrectEncryption
    }
        
    public enum Sync: Equatable {
        case syncing // in progress
        case synced // all done
    }
    
    case unknown
    case disabled
    case enabledNotAvailable(reason: NotAvailableReason)
    case enabled(sync: Sync)
}
