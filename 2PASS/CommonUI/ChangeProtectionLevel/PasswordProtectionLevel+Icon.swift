// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

extension ItemProtectionLevel {
    
    public var icon: Image {
        switch self {
        case .normal:
            Image(.tier3Icon)
        case .confirm:
            Image(.tier2Icon)
        case .topSecret:
            Image(.tier1Icon)
        }
    }
}
