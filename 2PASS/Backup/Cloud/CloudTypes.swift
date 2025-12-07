//
//  CloudTypes.swift
//  2PASS
//
//  Created by Zbigniew Cisiński on 06/12/2025.
//  Copyright © 2025 Two Factor Authentication Service, Inc. All rights reserved.
//

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
    
    public enum OutOfSyncReason: Equatable {
        case schemaNotSupported(Int)
    }
    
    public enum Sync: Equatable {
        case syncing // in progress
        case synced // all done
        case outOfSync(OutOfSyncReason)
        // case error(error: NSError) <- not used. Sync restarts itself
    }
    
    case unknown
    case disabled
    case enabledNotAvailable(reason: NotAvailableReason)
    case enabled(sync: Sync)
}
