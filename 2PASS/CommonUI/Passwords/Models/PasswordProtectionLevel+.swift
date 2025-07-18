// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public extension ItemProtectionLevel {
    var title: String {
        switch self {
        case .normal: T.settingsEntryProtectionLevel2
        case .confirm: T.settingsEntryProtectionLevel1
        case .topSecret: T.settingsEntryProtectionLevel0
        }
    }
    
    var description: String {
        switch self {
        case .normal: T.settingsEntryProtectionLevel2Description
        case .confirm: T.settingsEntryProtectionLevel1Description
        case .topSecret: T.settingsEntryProtectionLevel0Description
        }
    }
}
