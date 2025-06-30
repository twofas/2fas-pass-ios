// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum PasswordProtectionLevel: String, CaseIterable, Identifiable, Hashable, Codable {
    public var id: Self {
        self
    }
    case normal // Tier 3
    case confirm // Tier 2
    case topSecret // Tier 1
    
    public init(level: String) {
        if level == "normal" {
            self = .normal
        } else if level == "confirm" {
            self = .confirm
        } else {
            // default value
            self = .topSecret
        }
    }
    
    public static var `default`: Self {
        .normal
    }
}

extension PasswordProtectionLevel {
    
    public init?(intValue: Int) {
        switch intValue {
        case 0:
            self = .topSecret
        case 1:
            self = .confirm
        case 2:
            self = .normal
        default:
            return nil
        }
    }
    
    public var intValue: Int {
        switch self {
        case .topSecret:
            return 0
        case .confirm:
            return 1
        case .normal:
            return 2
        }
    }
}
