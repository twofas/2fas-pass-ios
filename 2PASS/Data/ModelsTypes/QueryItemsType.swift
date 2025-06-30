// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

enum QueryItemsType: Equatable {
    static func == (lhs: QueryItemsType, rhs: QueryItemsType) -> Bool {
        switch (lhs, rhs) {
        case (.entropy(_), .entropy(_)),
            (.masterKey(_), .masterKey(_)): true
        case (.other(let klhs, _), .other(let krhs, _)): klhs == krhs
        default: false
        }
    }
    
    case entropy(String)
    case masterKey(String)
    case other(String, String)
    
    init(key: String, value: String) {
        let entropy = "entropy"
        let masterKey = "master_key"
        
        if key == entropy {
            self = .entropy(value)
        } else if key == masterKey {
            self = .masterKey(value)
        } else {
            self = .other(key, value)
        }
    }
    
    var value: String {
        switch self {
        case .entropy(let item): item
        case .masterKey(let item): item
        case .other(_, let item): item
        }
    }
    
    var key: String {
        let entropy = "entropy"
        let masterKey = "master_key"
        
        switch self {
        case .other(let key, _):
            return key
        case .entropy:
            return entropy
        case .masterKey:
            return masterKey
        }
    }
}
