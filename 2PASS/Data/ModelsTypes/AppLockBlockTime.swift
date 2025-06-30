// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

// swiftlint:disable no_magic_numbers
public enum AppLockBlockTime: String, CaseIterable, Equatable {
    case min1 = "1 minute"
    case min3 = "3 minutes"
    case min5 = "5 minutes"
    case min15 = "15 minutes"
    case min60 = "1 hour"
    
    public var value: Int {
        switch self {
        case .min1: return 1
        case .min3: return 3
        case .min5: return 5
        case .min15: return 15
        case .min60: return 60
        }
    }
}
// swiftlint:enable no_magic_numbers
