// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public enum ItemTagColorMetrics {
    case small
    case regular
    case large
    
    public var size: CGFloat {
        switch self {
        case .small:
            12
        case .regular:
            14
        case .large:
            26
        }
    }
}
