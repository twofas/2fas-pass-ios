// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct SecureNoteDataChangeRequest: ItemDataChangeRequest {
    public let contentType: ItemContentType = .secureNote

    public var name: String?
    public var text: String?
    public var protectionLevel: ItemProtectionLevel?
    public var tags: [ItemTagID]?

    public init(name: String? = nil, text: String? = nil, protectionLevel: ItemProtectionLevel? = nil, tags: [ItemTagID]? = nil) {
        self.name = name
        self.text = text
        self.protectionLevel = protectionLevel
        self.tags = tags
    }
}
