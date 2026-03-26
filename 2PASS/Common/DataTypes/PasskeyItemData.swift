// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public typealias PasskeyItemData = _ItemData<PasskeyItemContent>

public struct PasskeyItemContent: ItemContent {

    public static let contentType: ItemContentType = .passkey
    public static let contentVersion = 1

    public let name: String?
    public let credentialId: Data
    public let rpId: String
    public let username: String
    public let userHandle: Data
    public let privateKey: Data

    public init(
        name: String?,
        credentialId: Data,
        rpId: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) {
        self.name = name
        self.credentialId = credentialId
        self.rpId = rpId
        self.username = username
        self.userHandle = userHandle
        self.privateKey = privateKey
    }

    public static let privateKeyCodingKey = "s_privateKey"

    enum CodingKeys: String, CodingKey {
        case name
        case credentialId
        case rpId
        case username
        case userHandle
        case privateKey = "s_privateKey"
    }
}

extension ItemData {

    public var asPasskeyItem: PasskeyItemData? {
        switch self {
        case .passkey(let passkeyItem): passkeyItem
        default: nil
        }
    }
}
