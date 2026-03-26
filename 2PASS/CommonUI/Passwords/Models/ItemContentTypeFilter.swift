// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

enum ItemContentTypeFilter: Equatable, Hashable {
    case all
    case contentType(ItemContentType)
    
    var contentType: ItemContentType? {
        switch self {
        case .all:
            return nil
        case .contentType(let contentType):
            return contentType
        }
    }
    
    static let allKnown: [ItemContentTypeFilter] = {
        let allContentTypes = ItemContentType.allKnownTypes
            .filter { $0 != .passkey }
            .map { ItemContentTypeFilter.contentType($0) }
        return [.all] + allContentTypes
    }()
}
