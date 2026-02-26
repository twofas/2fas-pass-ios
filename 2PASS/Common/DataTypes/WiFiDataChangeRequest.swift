// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct WiFiDataChangeRequest: ItemDataChangeRequest {
    public let contentType: ItemContentType = .wifi

    public var name: String?
    public var ssid: String?
    public var password: String?
    public var notes: String?
    public var securityType: WiFiContent.SecurityType?
    public var hidden: Bool?
    public var protectionLevel: ItemProtectionLevel?
    public var tags: [ItemTagID]?
    public let allowChangeContentType: Bool

    public init(
        name: String? = nil,
        ssid: String? = nil,
        password: String? = nil,
        notes: String? = nil,
        securityType: WiFiContent.SecurityType? = nil,
        hidden: Bool? = nil,
        protectionLevel: ItemProtectionLevel? = nil,
        tags: [ItemTagID]? = nil,
        allowChangeContentType: Bool = false
    ) {
        self.name = name
        self.ssid = ssid
        self.password = password
        self.notes = notes
        self.securityType = securityType
        self.hidden = hidden
        self.protectionLevel = protectionLevel
        self.tags = tags
        self.allowChangeContentType = allowChangeContentType
    }
}
