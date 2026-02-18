// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension FormatStyle where Self == WiFiSecurityTypeFormatStyle {
    public static var wifiSecurityType: WiFiSecurityTypeFormatStyle {
        .init()
    }
}

extension WiFiContent.SecurityType {

    public func formatted() -> String {
        WiFiSecurityTypeFormatStyle().format(self)
    }
}

public struct WiFiSecurityTypeFormatStyle: FormatStyle {

    public func format(_ securityType: WiFiContent.SecurityType) -> String {
        switch securityType {
        case .none:
            String(localized: .wifiSecurityTypeNone)
        case .wep, .wpa, .wpa2, .wpa3:
            securityType.rawValue.uppercased()
        }
    }
}
