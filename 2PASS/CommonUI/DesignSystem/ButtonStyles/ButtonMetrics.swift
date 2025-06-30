// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

enum ButtonLayoutType {
    case rectangle
    case circle
}

struct ButtonMetrics {
    
    let controlSize: ControlSize
    
    var horizontalPadding: CGFloat {
        switch controlSize {
        case .mini, .small: return 10
        case .regular: return 14
        case .large, .extraLarge: return 20
        @unknown default: return 14
        }
    }
    
    var height: CGFloat {
        switch controlSize {
        case .mini, .small: return 28
        case .regular: return 36
        case .large, .extraLarge: return 50
        @unknown default: return 36
        }
    }
    
    var cornerRadius: CGFloat {
        switch controlSize {
        case .mini, .small, .regular: return height / 2
        case .large, .extraLarge: return 12
        @unknown default: return height / 2
        }
    }
    
    var font: Font {
        switch controlSize {
        case .mini, .small, .regular:
            return .subheadline
        case .large, .extraLarge:
            return .body
        @unknown default:
            return .body
        }
    }
}
