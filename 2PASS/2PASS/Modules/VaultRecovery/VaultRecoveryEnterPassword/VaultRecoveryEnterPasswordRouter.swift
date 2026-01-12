// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data
import CommonUI

struct VaultRecoveryEnterPasswordRouter: Router {
    
    @ViewBuilder
    static func buildView(flowContext: VaultRecoveryFlowContext, entropy: Entropy, recoveryData: VaultRecoveryData)
    -> some View {
        let presenter = VaultRecoveryEnterPasswordPresenter(
            flowContext: flowContext,
            interactor: ModuleInteractorFactory.shared.vaultRecoveryEnterPasswordModuleInteractor(
                entropy: entropy,
                recoveryData: recoveryData,
            )
        )
        VaultRecoveryEnterPasswordView(presenter: presenter)
    }
    
    @ViewBuilder
    func view(for destination: VaultRecoveryEnterPasswordDestination) -> some View {
        switch destination {
        case let .recover(entropy, masterKey, recoveryData):
            VaultRecoveryRecoverRouter.buildView(
                kind: .recoverEncrypted(
                    entropy: entropy,
                    masterKey: masterKey,
                    recoveryData: recoveryData
                )
            )
        case .importVault(let entropy, let masterKey, let vault, let onClose):
            BackupImportImportingRouter.buildView(input: .encrypted(entropy: entropy, masterKey: masterKey, vault: vault), onClose: onClose)
        case .masterPasswordError:
            Button(.commonOk, action: {})
        }
    }
    
    func routingType(for destination: VaultRecoveryEnterPasswordDestination?) -> RoutingType? {
        switch destination {
        case .recover, .importVault: .push
        case .masterPasswordError(let message): .alert(title: String(localized: .commonError), message: message)
        default: nil
        }
    }
}
