// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

// swiftlint:disable no_magic_numbers
public enum AppLockAttempts: String, CaseIterable, Equatable {
    case try3 = "3 tries"
    case try5 = "5 tries"
    case try10 = "10 tries"
    case noLimit = "No Limit"
    
    public var value: Int {
        switch self {
        case .try3: return 3
        case .try5: return 5
        case .try10: return 10
        case .noLimit: return Int.max
        }
    }
}
// swiftlint:enable no_magic_numbers
