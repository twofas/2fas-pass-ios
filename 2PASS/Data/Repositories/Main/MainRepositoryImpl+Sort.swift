// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension MainRepositoryImpl {
    var sortType: SortType? {
        if cachedSortTypeInitialized {
            return cachedSortType
        }
        
        cachedSortType = userDefaultsDataSource.sortType
        cachedSortTypeInitialized = true
        return cachedSortType
    }
    
    func setSortType(_ sortType: SortType) {
        cachedSortType = sortType
        userDefaultsDataSource.setSortType(sortType)
    }
}
