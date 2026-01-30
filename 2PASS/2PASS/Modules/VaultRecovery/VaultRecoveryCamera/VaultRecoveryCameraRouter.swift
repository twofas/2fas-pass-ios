// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct VaultRecoveryCameraRouter: Router {

    @ViewBuilder
    static func buildView(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData, onTryAgain: @escaping Callback) -> some View {
        let presenter = VaultRecoveryCameraPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryCameraModuleInteractor(),
            flowContext: flowContext,
            recoveryData: recoveryData,
            onTryAgain: onTryAgain
        )
        VaultRecoveryCameraView(presenter: presenter)
    }

    @ViewBuilder
    func view(for destination: VaultRecoveryCameraDestination) -> some View {
        switch destination {
        case .vaultRecovery(let entropy, let masterKey, let recoveryData, let onTryAgain):
            VaultRecoveryRecoverRouter.buildView(
                kind: .recoverEncrypted(entropy: entropy, masterKey: masterKey, recoveryData: recoveryData),
                onTryAgain: onTryAgain
            )
        case .enterMasterPassword(let flowContext, let entropy, let recoveryData, let onTryAgain):
            VaultRecoveryEnterPasswordRouter.buildView(
                flowContext: flowContext,
                entropy: entropy,
                recoveryData: recoveryData,
                onTryAgain: onTryAgain
            )
        case .importVault(let input, let onClose):
            BackupImportImportingRouter.buildView(input: input, onClose: onClose)
        }
    }

    func routingType(for destination: VaultRecoveryCameraDestination?) -> RoutingType? {
        switch destination {
        case .vaultRecovery, .enterMasterPassword, .importVault: .push
        case nil: nil
        }
    }
}
