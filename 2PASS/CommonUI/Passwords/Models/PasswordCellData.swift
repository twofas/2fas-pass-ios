// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct PasswordCellData: Hashable {
    let itemID: ItemID
    let name: String?
    let username: String?
    let iconType: PasswordIconType
    let hasUsername: Bool
    let hasPassword: Bool
    let uris: [String]
    let normalizeURI: (String) -> URL?
}

extension PasswordCellData {
    static func == (lhs: PasswordCellData, rhs: PasswordCellData) -> Bool {
        return lhs.itemID == rhs.itemID &&
            lhs.name == rhs.name &&
            lhs.username == rhs.username &&
            lhs.iconType == rhs.iconType &&
            lhs.hasUsername == rhs.hasUsername &&
            lhs.hasPassword == rhs.hasPassword &&
            lhs.uris == rhs.uris
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(itemID)
        hasher.combine(name)
        hasher.combine(username)
        hasher.combine(iconType)
        hasher.combine(hasUsername)
        hasher.combine(hasPassword)
        hasher.combine(uris)
    }
}

extension PasswordCellData: Identifiable {
    var id: ItemID { itemID }
}
