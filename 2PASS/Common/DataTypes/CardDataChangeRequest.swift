// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct CardDataChangeRequest: ItemDataChangeRequest {
    public let contentType: ItemContentType = .card

    public var name: String?
    public var cardHolder: String?
    public var cardNumber: String?
    public var expirationDate: String?
    public var securityCode: String?
    public var notes: String?
    public var protectionLevel: ItemProtectionLevel?
    public var tags: [ItemTagID]?
    public let allowChangeContentType: Bool

    public init(
        name: String? = nil,
        cardHolder: String? = nil,
        cardNumber: String? = nil,
        expirationDate: String? = nil,
        securityCode: String? = nil,
        notes: String? = nil,
        protectionLevel: ItemProtectionLevel? = nil,
        tags: [ItemTagID]? = nil,
        allowChangeContentType: Bool = false
    ) {
        self.name = name
        self.cardHolder = cardHolder
        self.cardNumber = cardNumber
        self.expirationDate = expirationDate
        self.securityCode = securityCode
        self.notes = notes
        self.protectionLevel = protectionLevel
        self.tags = tags
        self.allowChangeContentType = allowChangeContentType
    }
}
