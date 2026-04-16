// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public typealias WiFiItemData          = _ItemData<WiFiContent>
public typealias WiFiItemDecryptedData = _ItemData<WiFiDecryptedContent>

public typealias WiFiContent          = _WiFiContent<Encrypted>
public typealias WiFiDecryptedContent = _WiFiContent<Decrypted>

public enum WiFiSecurityType: String, Hashable, Codable, CaseIterable {
    case none
    case wep
    case wpa
    case wpa2
    case wpa3
}

public struct _WiFiContent<State: EncryptionState>: ItemContent, CustomDebugStringConvertible {

    public typealias SecurityType = WiFiSecurityType

    public static var contentType: ItemContentType { .wifi }
    public static var contentVersion: Int { 1 }

    public let name: String?
    public let ssid: String?
    public let password: State.SecureField?
    public let notes: String?
    public let securityType: SecurityType
    public let hidden: Bool

    private enum CodingKeys: String, CodingKey {
        case name
        case ssid
        case password = "s_password"
        case notes
        case securityType
        case hidden
    }

    public var debugDescription: String {
        "WiFiContent(name: \(name ?? "nil"), ssid: \(ssid ?? "nil"), password: <redacted>, securityType: \(securityType.rawValue), hidden: \(hidden))"
    }
}

extension WiFiContent {

    public init(
        name: String?,
        ssid: String?,
        password: Data?,
        notes: String? = nil,
        securityType: SecurityType,
        hidden: Bool
    ) {
        self.name = name
        self.ssid = ssid
        self.password = password
        self.notes = notes
        self.securityType = securityType
        self.hidden = hidden
    }
}

extension WiFiDecryptedContent {

    public init(
        name: String?,
        ssid: String?,
        password: String?,
        notes: String? = nil,
        securityType: SecurityType,
        hidden: Bool
    ) {
        self.name = name
        self.ssid = ssid
        self.password = password
        self.notes = notes
        self.securityType = securityType
        self.hidden = hidden
    }
}

extension WiFiContent.SecurityType {

    public var isWPA: Bool {
        switch self {
        case .wpa, .wpa2, .wpa3:
            true
        case .none, .wep:
            false
        }
    }
}

extension ItemData {

    public var asWiFi: WiFiItemData? {
        switch self {
        case .wifi(let wifiItem): wifiItem
        default: nil
        }
    }
}

extension ItemDecryptedData {

    public var asWiFi: WiFiItemDecryptedData? {
        switch self {
        case .wifi(let wifiItem): wifiItem
        default: nil
        }
    }
}
