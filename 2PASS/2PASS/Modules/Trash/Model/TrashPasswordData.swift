// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct TrashPasswordData: Identifiable, Hashable {
    var id: ItemID {
        itemID
    }
    let itemID: ItemID
    let name: String?
    let username: String?
    let deletedDate: Date
    let iconType: PasswordIconType
}
