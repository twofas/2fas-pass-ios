// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension MainRepositoryImpl {
    func uriCacheSet(originalUri: String, parsedUri: String) {
        cachedUri[originalUri] = parsedUri
    }
    
    func uriCacheGet(originalUri: String) -> String? {
        cachedUri[originalUri]
    }
}
