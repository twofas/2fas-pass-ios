// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct ItemCellData: Hashable {
    let itemID: ItemID
    let name: String?
    let description: String?
    let iconType: Icon
    let actions: [PasswordCellMenu]
}

extension ItemCellData {

    enum Icon: Hashable {
        case login(PasswordIconType)
        case contentType(ItemContentType)
        case paymentCard(issuer: String?)

        var iconURL: URL? {
            guard case .login(let value) = self else {
                return nil
            }
            return value.iconURL
        }
    }
}

extension ItemCellData: Identifiable {
    var id: ItemID { itemID }
}
