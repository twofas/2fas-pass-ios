// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol CustomizationModuleInteracting: AnyObject {
    var deviceName: String { get }
    func setDeviceName(_ name: String)
    var defaultPassswordListAction: PasswordListAction { get }
    func setDefaultPassswordListAction(_ action: PasswordListAction)
}

final class CustomizationModuleInteractor: CustomizationModuleInteracting {

    private let configInteractor: ConfigInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting

    init(configInteractor: ConfigInteracting, syncChangeTriggerInteractor: SyncChangeTriggerInteracting) {
        self.configInteractor = configInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
    }
    
    var deviceName: String {
        configInteractor.deviceName
    }

    func setDeviceName(_ name: String) {
        configInteractor.setDeviceName(name)
        syncChangeTriggerInteractor.trigger()
    }

    var defaultPassswordListAction: PasswordListAction {
        configInteractor.defaultPassswordListAction
    }
    
    func setDefaultPassswordListAction(_ action: PasswordListAction) {
        configInteractor.setDefaultPassswordListAction(action)
    }
}
