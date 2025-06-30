// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol VaultRecoveryEnterPasswordModuleInteracting: AnyObject {
    var entropy: Entropy { get }
    var recoveryData: VaultRecoveryData { get }
    func masterPasswordToMasterKey(
        _ masterPassword: MasterPassword,
        completion: @escaping (MasterKey?) -> Void
    )
}

final class VaultRecoveryEnterPasswordModuleInteractor {
    let entropy: Entropy
    let recoveryData: VaultRecoveryData
    private let loginInteractor: LoginInteracting
    private let jsonDecoder: JSONDecoder
        
    init(
        entropy: Entropy,
        recoveryData: VaultRecoveryData,
        loginInteractor: LoginInteracting
    ) {
        self.entropy = entropy
        self.recoveryData = recoveryData
        self.loginInteractor = loginInteractor
        self.jsonDecoder = JSONDecoder()
    }
}

extension VaultRecoveryEnterPasswordModuleInteractor: VaultRecoveryEnterPasswordModuleInteracting {
    func masterPasswordToMasterKey(_ masterPassword: MasterPassword, completion: @escaping (MasterKey?) -> Void) {
        switch recoveryData {
        case .cloud(let vault):
            loginInteractor.verifyMasterPassword(
                using: masterPassword,
                entropy: entropy,
                seedHashHex: vault.seedHash,
                reference: vault.reference,
                vaultID: vault.vaultID,
                kdfSpec: try? jsonDecoder.decode(KDFSpec.self, from: vault.kdfSpec),
                completion: completion
            )
        case .file(let exchangeVault):
            let uuidString = exchangeVault.vault.id
            guard let seedHashHex = exchangeVault.encryption?.seedHash,
                  let reference = exchangeVault.encryption?.reference,
                  let kdfSpecVault = exchangeVault.encryption?.kdfSpec,
                  let vaultID = UUID(uuidString: uuidString),
                  let kdfSpec = KDFSpec(kdfSpecVault)
            else {
                Log(
                    "VaultRecoveryEnterPasswordModuleInteractor: Can't gather necessary elements for Master Password validation",
                    module: .moduleInteractor,
                    severity: .error
                )
                completion(nil)
                return
            }
            loginInteractor.verifyMasterPassword(
                using: masterPassword,
                entropy: entropy,
                seedHashHex: seedHashHex,
                reference: reference,
                vaultID: vaultID,
                kdfSpec: kdfSpec,
                completion: completion
            )
        }
    }
}
