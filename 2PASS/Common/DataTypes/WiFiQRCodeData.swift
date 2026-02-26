// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct WiFiQRCodeData: Hashable {
    public let ssid: String
    public let password: String?
    public let securityType: WiFiContent.SecurityType
    public let hidden: Bool

    public init(
        ssid: String,
        password: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) {
        self.ssid = ssid
        self.password = password
        self.securityType = securityType
        self.hidden = hidden
    }
}
