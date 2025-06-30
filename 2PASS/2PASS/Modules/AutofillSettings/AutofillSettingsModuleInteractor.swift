// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol AutofillSettingsModuleInteracting: AnyObject {
    var isAutoFillEnabled: Bool { get }
    
    func turnOnAutoFill()
    func turnOffAutoFill()
    func openAutoFillSystemSettings()
    
    var didAutoFillStatusChanged: NotificationCenter.Notifications { get }
}

final class AutofillSettingsModuleInteractor: AutofillSettingsModuleInteracting {
    
    let autoFillStatusInteractor: AutoFillStatusInteracting
    
    init(autoFillStatusInteractor: AutoFillStatusInteracting) {
        self.autoFillStatusInteractor = autoFillStatusInteractor
    }
    
    var isAutoFillEnabled: Bool {
        autoFillStatusInteractor.isEnabled
    }
    
    var didAutoFillStatusChanged: NotificationCenter.Notifications {
        autoFillStatusInteractor.didStatusChanged
    }
    
    func turnOnAutoFill() {
        autoFillStatusInteractor.turnOn()
    }
    
    func turnOffAutoFill() {
        autoFillStatusInteractor.turnOff()
    }
    
    func openAutoFillSystemSettings() {
        autoFillStatusInteractor.openAutoFillSystemSettings()
    }
}
