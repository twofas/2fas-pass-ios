// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

enum RecordType: String {
    case password = "Password" // deprecated
    case item = "Item"
    case deletedItem = "DeletedItem"
    case tag = "Tag"
    case vault = "Vault"
}
