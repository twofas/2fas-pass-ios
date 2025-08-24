// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public struct ItemTagData: Identifiable, Hashable {
    public var id: UUID { tagID }
    
    public let tagID: ItemTagID
    public let vaultID: VaultID
    public var name: String
    public let color: UIColor?
    public let position: Int
    public var modificationDate: Date
    
    public init(tagID: ItemTagID, vaultID: VaultID, name: String, color: UIColor?, position: Int, modificationDate: Date) {
        self.tagID = tagID
        self.vaultID = vaultID
        self.name = name
        self.color = color
        self.position = position
        self.modificationDate = modificationDate
    }
}
