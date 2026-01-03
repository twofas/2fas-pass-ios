// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public enum ItemTagColor: Hashable {
    
    public static var allKnownCases: [ItemTagColor] {
        [.gray, .red, .orange, .yellow, .green, .cyan, .indigo, .purple]
    }
    
    case gray
    case red
    case orange
    case yellow
    case green
    case cyan
    case indigo
    case purple
    case unknown(String?)
    
    public var rawValue: String? {
        switch self {
        case .gray: "gray"
        case .red: "red"
        case .orange: "orange"
        case .yellow: "yellow"
        case .green: "green"
        case .cyan: "cyan"
        case .indigo: "indigo"
        case .purple: "purple"
        case .unknown(let value): value
        }
    }

    public init(rawValue: String?) {
        switch rawValue {
        case "gray": self = .gray
        case "red": self = .red
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "green": self = .green
        case "cyan": self = .cyan
        case "indigo": self = .indigo
        case "purple": self = .purple
        default: self = .unknown(rawValue)
        }
    }
}

extension ItemTagColor {
    
    public var isUnknown: Bool {
        switch self {
        case .unknown: true
        default: false
        }
    }
}
