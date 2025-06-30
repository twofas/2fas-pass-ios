// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct URI: Hashable, Identifiable {
    let id: UUID
    var uri: String
    var match: PasswordURI.Match
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func empty() -> URI {
        .init(id: UUID(), uri: "", match: .domain)
    }
}
