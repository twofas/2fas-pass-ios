// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension MainRepositoryImpl {
    var isUserLoggedIn: Bool {
        _empheralSecureKey != nil
    }
    
    var isAppInBackground: Bool {
        _isInBackground
    }
    
    func setIsAppInBackground(_ isInBackground: Bool) {
        _isInBackground = isInBackground
    }
    
    var canLockApp: Bool {
        _canLockApp
    }
    
    func blockAppLocking() {
        _canLockApp = false
    }
    
    func unblockAppLocking() {
        _canLockApp = true
    }
}
