// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol ShareContent: Codable {}

public struct ShareLoginContent: ShareContent {
    
    public struct URI: Codable {
        public let text: String
        public let matcher: Int
    }
    
    public let name: String?
    public let username: String?
    public let password: String?
    public let notes: String?
    public let uris: [URI]?
}

public struct ShareSecureNoteContent: ShareContent {
    public let name: String?
    public let text: String?
}

public struct SharePaymentCardContent: ShareContent {
    public let name: String?
    public let cardHolder: String?
    public let cardNumber: String?
    public let expirationDate: String?
    public let securityCode: String?
    public let notes: String?
}

public struct ShareWiFiContent: ShareContent {
    public let name: String?
    public let ssid: String?
    public let password: String?
    public let notes: String?
    public let securityType: WiFiContent.SecurityType?
    public let hidden: Bool?
}

public struct ShareCustomContent: ShareContent {
    public let text: String?
}
