// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol CustomizationModuleInteracting: AnyObject {
    var deviceName: String { get }
    var defaultPassswordListAction: PasswordListAction { get }
    func setDefaultPassswordListAction(_ action: PasswordListAction)
}

final class CustomizationModuleInteractor: CustomizationModuleInteracting {
    
    private let configInteractor: ConfigInteracting
    
    init(configInteractor: ConfigInteracting) {
        self.configInteractor = configInteractor
    }
    
    var deviceName: String {
        configInteractor.deviceName
    }
    
    var defaultPassswordListAction: PasswordListAction {
        configInteractor.defaultPassswordListAction
    }
    
    func setDefaultPassswordListAction(_ action: PasswordListAction) {
        configInteractor.setDefaultPassswordListAction(action)
    }
}
