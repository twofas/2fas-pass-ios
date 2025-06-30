// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct DeletedItemData: Hashable, Identifiable {
    
    public enum Kind: String {
        case login
        case tag
    }
    
    public var id: UUID {
        itemID
    }
    
    public let itemID: DeletedItemID
    public let vaultID: VaultID
    public let kind: Kind
    public let deletedAt: Date
    
    public init(itemID: DeletedItemID, vaultID: VaultID, kind: Kind, deletedAt: Date) {
        self.itemID = itemID
        self.vaultID = vaultID
        self.kind = kind
        self.deletedAt = deletedAt
    }
}
