// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension Sequence where Iterator.Element == URLQueryItem {
    func find(forKey key: String) -> String? {
        first(where: { $0.name == key })?.value
    }
}

extension Sequence where Iterator.Element == QueryItemsType {
    func contains(forType type: QueryItemsType) -> Bool {
        contains(where: { $0 == type })
    }
    
    func find(forType type: QueryItemsType) -> QueryItemsType? {
        first(where: { $0 == type })
    }
}
