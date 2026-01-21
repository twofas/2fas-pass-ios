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
        case .normal: String(localized: .settingsEntryProtectionLevel2)
        case .confirm: String(localized: .settingsEntryProtectionLevel1)
        case .topSecret: String(localized: .settingsEntryProtectionLevel0)
        }
    }
    
    var description: LocalizedStringResource {
        switch self {
        case .normal: .settingsEntryProtectionLevel2Description
        case .confirm: .settingsEntryProtectionLevel1Description
        case .topSecret: .settingsEntryProtectionLevel0Description
        }
    }
}
