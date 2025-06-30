// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import SwiftUI

@Observable
final class AutofillSettingsPresenter {
    
    var isEnabled: Bool {
        get {
            _isEnabled
        }
        set {
            if newValue {
                interactor.turnOnAutoFill()
            } else {
                interactor.turnOffAutoFill()
            }
        }
    }
    private var _isEnabled: Bool = false
    
    private let interactor: AutofillSettingsModuleInteracting
    
    init(interactor: AutofillSettingsModuleInteracting) {
        self.interactor = interactor
        self._isEnabled = interactor.isAutoFillEnabled
    }
    
    func onSystemSettings() {
        interactor.openAutoFillSystemSettings()
    }
    
    func observeAutoFillStatusChanged() async {
        for await _ in interactor.didAutoFillStatusChanged {
            _isEnabled = interactor.isAutoFillEnabled
        }
    }
}
