// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct PasswordCellData: Hashable {
    let passwordID: PasswordID
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
        return lhs.passwordID == rhs.passwordID &&
            lhs.name == rhs.name &&
            lhs.username == rhs.username &&
            lhs.iconType == rhs.iconType &&
            lhs.hasUsername == rhs.hasUsername &&
            lhs.hasPassword == rhs.hasPassword &&
            lhs.uris == rhs.uris
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(passwordID)
        hasher.combine(name)
        hasher.combine(username)
        hasher.combine(iconType)
        hasher.combine(hasUsername)
        hasher.combine(hasPassword)
        hasher.combine(uris)
    }
}

extension PasswordCellData: Identifiable {
    var id: PasswordID { passwordID }
}
