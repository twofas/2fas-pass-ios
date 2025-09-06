// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

final class ChangeMasterPasswordModuleInteractor {
    private let changePasswordInteractor: ChangePasswordInteracting
    
    init(changePasswordInteractor: ChangePasswordInteracting) {
        self.changePasswordInteractor = changePasswordInteractor
    }
}

extension ChangeMasterPasswordModuleInteractor: MasterPasswordModuleInteracting {
    var passwords: [Common.ItemData]? { nil }
    
    var isBiometryAvailable: Bool {
        changePasswordInteractor.isBiometryAvailable
    }
    
    func createMasterPassword(
        _ masterPassword: MasterPassword,
        enableBiometryLogin: Bool,
        completion: @escaping () -> Void
    ) {
        changePasswordInteractor.changeMasterPassword(
            masterPassword,
            completion: completion
        )
    }
}
