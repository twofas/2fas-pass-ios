// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol MasterPasswordModuleInteracting: AnyObject {
    var isBiometryAvailable: Bool { get }
    func createMasterPassword(
        _ masterPassword: MasterPassword,
        enableBiometryLogin: Bool,
        completion: @escaping () -> Void
    )
}

final class MasterPasswordModuleInteractor {
    private let startupInteractor: StartupInteracting
    private let setupEncryption: Bool
    
    init(startupInteractor: StartupInteracting, setupEncryption: Bool) {
        self.startupInteractor = startupInteractor
        self.setupEncryption = setupEncryption
    }
}

extension MasterPasswordModuleInteractor: MasterPasswordModuleInteracting {
    var isBiometryAvailable: Bool {
        startupInteractor.canUseBiometry
    }
    
    func createMasterPassword(
        _ masterPassword: MasterPassword,
        enableBiometryLogin: Bool,
        completion: @escaping () -> Void
    ) {
        if setupEncryption {
            startupInteractor.setupEncryptionElements()
        }
        startupInteractor.setMasterPassword(
            masterPassword: masterPassword,
            enableBiometryLogin: enableBiometryLogin,
            completion: completion
        )
    }
}
