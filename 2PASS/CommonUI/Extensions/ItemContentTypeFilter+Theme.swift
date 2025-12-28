// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

extension ItemContentTypeFilter {
    
    var title: String {
        ItemContentTypeFilterFormatStyle().format(self)
    }
    
    var iconSystemName: String {
        switch self {
        case .all:
            "briefcase.fill"
        case .contentType(.login):
            "person.crop.square.fill"
        case .contentType(.secureNote):
            "note.text"
        case .contentType(.unknown):
            ""
        }
    }
    
    var color: UIColor {
        switch self {
        case .all:
            UIColor(hexString: "#214CE8")!
        case .contentType(let type):
            type.primaryColor
        }
    }
}
