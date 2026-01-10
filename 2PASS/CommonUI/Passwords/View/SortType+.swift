// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

extension SortType {
    var label: String {
        switch self {
        case .newestFirst: String(localized: .loginFilterModalSortCreationDateDesc)
        case .oldestFirst: String(localized: .loginFilterModalSortCreationDateAsc)
        case .az: String(localized: .loginFilterModalSortNameAsc)
        case .za: String(localized: .loginFilterModalSortNameDesc)
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .newestFirst, .oldestFirst: UIImage(systemName: "calendar")
        case .az, .za: UIImage(systemName: "abc")
        }
    }
}
