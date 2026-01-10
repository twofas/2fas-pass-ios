// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct VaultRecoverySelectRouter: Router {
    
    @ViewBuilder
    static func buildView(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData)
    -> some View {
        let presenter = VaultRecoverySelectPresenter(
            flowContext: flowContext,
            interactor: ModuleInteractorFactory.shared.vaultRecoverySelectModuleInteractor(),
            recoveryData: recoveryData,
        )
        VaultRecoverySelectView(presenter: presenter)
    }
    
    @ViewBuilder
    func view(for destination: VaultRecoverySelectDestination) -> some View {
        switch destination {
        case .camera(let flowContext, let recoveryData):
            VaultRecoveryScanQRCodeIntroRouter.buildView(flowContext: flowContext, recoveryData: recoveryData)
        case .manually(let recoveryData, let onEntropy):
            VaultRecoveryEnterWordsRouter.buildView(recoveryData: recoveryData, onEntropy: onEntropy)
        case .errorOpeningFile(_, let onClose):
            Button(.commonOk, action: onClose)
        case .vaultRecovery(let entropy, let masterKey, let recoveryData):
            VaultRecoveryRecoverRouter.buildView(
                kind: .recoverEncrypted(entropy: entropy, masterKey: masterKey, recoveryData: recoveryData)
            )
        case .importVault(let input, let onClose):
            BackupImportImportingRouter.buildView(input: input, onClose: onClose)
        case .enterMasterPassword(let flowContext, let entropy, let recoveryData):
            VaultRecoveryEnterPasswordRouter.buildView(flowContext: flowContext, entropy: entropy, recoveryData: recoveryData)
        case .importFailed(let onSelectVault, let onSelectDecryptionKit):
            VaultRecoveryWrongDecryptionKitRouter.buildView(onSelectVault: onSelectVault, onSelectDecryptionKit: onSelectDecryptionKit)
        }
    }
    
    func routingType(for destination: VaultRecoverySelectDestination?) -> RoutingType? {
        switch destination {
        case .manually: .sheet
        case .camera, .enterMasterPassword, .vaultRecovery, .importVault, .importFailed: .push
        case .errorOpeningFile(let message, _): .alert(title: String(localized: .commonError), message: message)
        case nil: nil
        }
    }
}
