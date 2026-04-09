// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

/// Decodes only the `contentType` field, ignoring `content`.
struct ShareSecretHeader: Decodable {
    let contentType: String
    let contentVersion: Int
}

public struct ShareSecretContent<T>: Codable where T: ShareContent {
    public let contentType: String
    public let contentVersion: Int
    public let content: T

    public init(contentType: String, contentVersion: Int, content: T) {
        self.contentType = contentType
        self.contentVersion = contentVersion
        self.content = content
    }
}

struct ShareSecretRequest: Encodable {
    let data: Data
    let validForSeconds: Int
    let singleUse: Bool
}

public struct CreateShareSecretResponse: Decodable {
    public let id: String
    public let validUntil: String
    public let singleUse: Bool

    public init(id: String, validUntil: String, singleUse: Bool) {
        self.id = id
        self.validUntil = validUntil
        self.singleUse = singleUse
    }
}

public struct SharedSecretResponse: Decodable {
    public let data: String

    public init(data: String) {
        self.data = data
    }
}
