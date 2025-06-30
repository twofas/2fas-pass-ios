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
        case .newestFirst: T.loginFilterModalSortCreationDateDesc
        case .oldestFirst: T.loginFilterModalSortCreationDateAsc
        case .az: T.loginFilterModalSortNameAsc
        case .za: T.loginFilterModalSortNameDesc
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .newestFirst, .oldestFirst: UIImage(systemName: "calendar")
        case .az, .za: UIImage(systemName: "abc")
        }
    }
}
