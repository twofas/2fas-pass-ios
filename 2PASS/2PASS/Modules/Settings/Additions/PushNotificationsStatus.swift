// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

enum PushNotificationsStatus {
    case unknown
    case on
    case off
}
 
struct PushNotificationsStatusFormatStyle: FormatStyle {
    
    func format(_ value: PushNotificationsStatus) -> String {
        switch value {
        case .unknown:
            return ""
        case .on:
            return String(localized: .commonOn)
        case .off:
            return String(localized: .commonOff)
        }
    }
}

extension Text {
    
    init(_ status: PushNotificationsStatus) {
        self.init(PushNotificationsStatusFormatStyle().format(status))
    }
}
