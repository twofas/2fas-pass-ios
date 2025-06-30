// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol ChangePasswordInteracting: AnyObject {
    var isBiometryAvailable: Bool { get }
    func changeMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping () -> Void
    )
}

final class ChangePasswordInteractor {
    private let biometryInteractor: BiometryInteracting
    private let passwordInteractor: PasswordInteracting
    private let protectionInteractor: ProtectionInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    
    init(
        biometryInteractor: BiometryInteracting,
        passwordInteractor: PasswordInteracting,
        protectionInteractor: ProtectionInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    ) {
        self.biometryInteractor = biometryInteractor
        self.passwordInteractor = passwordInteractor
        self.protectionInteractor = protectionInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
    }
}

extension ChangePasswordInteractor: ChangePasswordInteracting {
    var isBiometryAvailable: Bool {
        biometryInteractor.isBiometryAvailable
    }
    
    func changeMasterPassword(
        _ masterPassword: MasterPassword,
        completion: @escaping () -> Void
    ) {
        let (current, tags) = passwordInteractor.getCompleteDecryptedList()
        let enableBiometryLogin = biometryInteractor.canUseBiometryForLogin
        Log(
            "ChangePasswordInteractor: Changing Master Password. Enable biometry: \(enableBiometryLogin)",
            module: .interactor
        )
        protectionInteractor.setMasterKey(for: masterPassword)
        biometryInteractor.setBiometryEnabled(enableBiometryLogin) { [weak self] result in
            self?.protectionInteractor.saveEncryptionReference()
            self?.protectionInteractor.updateExistingVault()
            self?.protectionInteractor.setupKeys()
            self?.passwordInteractor.reencryptDecryptedList(current, tags: tags, completion: { [weak self] _ in
                self?.syncChangeTriggerInteractor.setPasswordWasChanged()
                completion()
                self?.syncChangeTriggerInteractor.trigger()
            })
        }
    }
}
