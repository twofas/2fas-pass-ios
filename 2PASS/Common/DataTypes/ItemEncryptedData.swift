// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum ItemContentType: String {
    case login
}

public struct ItemEncryptedData: Hashable, Identifiable {
    public var id: UUID {
        itemID
    }
    
    public let itemID: PasswordID
    public let creationDate: Date
    public let modificationDate: Date
    public let trashedStatus: ItemTrashedStatus
    public let protectionLevel: ItemProtectionLevel
    public let contentType: ItemContentType
    public let content: Data
    public let contentVersion: Int
    public let vaultID: VaultID
    public let tagIds: [ItemTagID]?
    
    public init(
        itemID: PasswordID,
        creationDate: Date,
        modificationDate: Date,
        trashedStatus: ItemTrashedStatus,
        protectionLevel: ItemProtectionLevel,
        contentType: ItemContentType,
        contentVersion: Int,
        content: Data,
        vaultID: VaultID,
        tagIds: [ItemTagID]?
    ) {
        self.itemID = itemID
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.trashedStatus = trashedStatus
        self.protectionLevel = protectionLevel
        self.content = content
        self.contentVersion = contentVersion
        self.contentType = contentType
        self.vaultID = vaultID
        self.tagIds = tagIds
    }
}
