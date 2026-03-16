// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

enum CloudKitAction {
    enum Reason {
        case iCloudProblem
        case quotaExceeded
        case userDisablediCloud
        case notLoggedIn
    }
    case retry(after: TimeInterval)
    case resetAndRetry(after: TimeInterval)
    case stop(reason: Reason)
    
    var weight: Int {
        switch self {
        case .retry: return 1
        case .resetAndRetry: return 2
        case .stop: return 3
        }
    }
}

extension Collection where Element == CloudKitAction {
    var sortedByImportance: [CloudKitAction] {
        sorted(by: { $0.weight < $1.weight })
    }
}

// swiftlint:disable legacy_objc_type
final class CloudKitErrorParser {
    private let retryIntervals: [TimeInterval] = [2, 5, 10, 30, 60]
    private let offlineRetryInterval: TimeInterval = 600

    private func retryInterval(for retryCount: Int) -> TimeInterval {
        retryIntervals[min(retryCount, retryIntervals.count - 1)]
    }

    func handle(error: NSError, retryCount: Int) -> CloudKitAction? {
        let userInfo = error.userInfo
        
        Log("Handling error \(error)", module: .cloudSync)
        
        if error.isOffline {
            Log("iCloud is offline, retrying in \(offlineRetryInterval)s", module: .cloudSync)
            return .retry(after: offlineRetryInterval)
        }
        
        if let retry = userInfo[CKErrorRetryAfterKey] as? NSNumber {
            let seconds = TimeInterval(retry.doubleValue)
            Log("Should retry in \(seconds) because of error: \(error). Purging and retrying", module: .cloudSync)
            return .retry(after: seconds)
        }
        
        guard let errorCode = CKError.Code(rawValue: error.code) else {
            let interval = retryInterval(for: retryCount)
            Log("Can't get error code from \(error). Purging and retrying in \(interval)s", module: .cloudSync)
            return .resetAndRetry(after: interval)
        }
        
        Log("Error code: \(errorCode)", module: .cloudSync)
        
        switch errorCode {
        case .internalError, .zoneNotFound, .serverResponseLost:
            return .resetAndRetry(after: retryInterval(for: retryCount))

        case .networkUnavailable,
            .networkFailure,
            .serviceUnavailable,
            .requestRateLimited,
            .limitExceeded,
            .zoneBusy:
            return .resetAndRetry(after: retryInterval(for: retryCount))

        case .operationCancelled:
            Log("Operation cancelled!", module: .cloudSync)
            return nil

        case .changeTokenExpired,
                .serverRecordChanged,
                .unknownItem,
                .constraintViolation,
                .invalidArguments,
                .batchRequestFailed:
            return .resetAndRetry(after: retryInterval(for: retryCount))
            
        case .missingEntitlement,
            .serverRejectedRequest,
            .managedAccountRestricted,
            .badContainer,
            .incompatibleVersion,
            .badDatabase,
            .accountTemporarilyUnavailable:
            return .stop(reason: .iCloudProblem)
            
        case .quotaExceeded:
            return .stop(reason: .quotaExceeded)
            
        case .permissionFailure, .notAuthenticated:
            return .stop(reason: .notLoggedIn)
            
        case .userDeletedZone:
            return .stop(reason: .userDisablediCloud)
            
        default:
            Log("No handler for error \(error)", module: .cloudSync)
            return nil
        }
    }
}
// swiftlint:enable legacy_objc_type

private extension NSError {
    var isOffline: Bool {
        code == -1009
    }
}
