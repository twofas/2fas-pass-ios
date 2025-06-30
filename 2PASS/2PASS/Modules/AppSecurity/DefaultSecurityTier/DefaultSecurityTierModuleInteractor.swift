// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common

protocol DefaultSecurityTierModuleInteracting: AnyObject {
    var defaultSecurityTier: PasswordProtectionLevel { get set }
}

final class DefaultSecurityTierModuleInteractor: DefaultSecurityTierModuleInteracting {
    
    var defaultSecurityTier: PasswordProtectionLevel {
        get {
            configInteractor.currentDefaultProtectionLevel
        }
        set {
            configInteractor.setDefaultProtectionLevel(newValue)
        }
    }
    
    private let configInteractor: ConfigInteracting
    
    init(configInteractor: ConfigInteracting) {
        self.configInteractor = configInteractor
    }
}
