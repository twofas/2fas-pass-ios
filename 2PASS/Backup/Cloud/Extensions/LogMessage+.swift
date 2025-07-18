// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CloudKit
import Common

extension LogMessage.Interpolation {
        
    public mutating func appendInterpolation(_ value: @autoclosure () -> CKAccountStatus, privacy: LogPrivacy = .auto) {
        let description = {
            switch value() {
            case .available:
                return "Available"
            case .restricted:
                return "Restricted"
            case .noAccount:
                return "No Account"
            case .temporarilyUnavailable:
                return "Temporarily Unavailable"
            case .couldNotDetermine:
                return "Could Not Determine"
            @unknown default:
                return "Unknown"
            }
        }()
        appendInterpolation(description, privacy: privacy == .auto ? .public : privacy)
    }
}


extension LogMessage.Interpolation {
    
    public mutating func appendInterpolation(_ value: @autoclosure () -> CloudCurrentState, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
}

extension LogMessage.Interpolation {
    
    mutating func appendInterpolation(_ value: @autoclosure () -> CloudAvailabilityStatus, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
}

extension LogMessage.Interpolation {
    
    public mutating func appendInterpolation(_ value: @autoclosure () -> CKError.Code, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
}
