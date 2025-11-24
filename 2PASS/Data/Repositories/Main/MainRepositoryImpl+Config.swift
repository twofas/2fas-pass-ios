// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension MainRepositoryImpl {
    var currentDefaultProtectionLevel: ItemProtectionLevel {
        userDefaultsDataSource.currentDefaultProtectionLevel
    }
    
    func setDefaultProtectionLevel(_ value: ItemProtectionLevel) {
        userDefaultsDataSource.setDefaultProtectionLevel(value)
    }
    
    var passwordGeneratorConfig: Data? {
        userDefaultsDataSource.passwordGeneratorConfig
    }
    func setPasswordGeneratorConfig(_ data: Data) {
        userDefaultsDataSource.setPasswordGeneratorConfig(data)
    }
    
    var defaultPassswordListAction: PasswordListAction {
        let action = userDefaultsDataSource.defaultPassswordListAction
        if action == .goToURI {
            return .viewDetails
        } else {
            return action
        }
    }
    
    func setDefaultPassswordListAction(_ action: PasswordListAction) {
        userDefaultsDataSource.setDefaultPassswordListAction(action)
    }
}
