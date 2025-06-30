// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct ItemTagEncryptedData: Identifiable, Hashable {
    public var id: UUID { tagID }
    public let tagID: ItemTagID
    public let vaultID: VaultID
    public let name: Data
    public let color: String?
    public let position: Int
    public let modificationDate: Date
    
    public init(tagID: UUID, vaultID: UUID, name: Data, color: String?, position: Int, modificationDate: Date) {
        self.tagID = tagID
        self.vaultID = vaultID
        self.name = name
        self.color = color
        self.position = position
        self.modificationDate = modificationDate
    }
}
