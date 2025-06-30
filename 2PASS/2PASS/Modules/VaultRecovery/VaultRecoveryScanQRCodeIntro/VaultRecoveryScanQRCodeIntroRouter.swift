// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryScanQRCodeIntroRouter: Router {
    
    static func buildView(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData) -> some View {
        VaultRecoveryScanQRCodeIntroView(presenter: .init(flowContext: flowContext, recoveryData: recoveryData))
    }
    
    func routingType(for destination: VaultRecoveryScanQRCodeIntroDestination?) -> RoutingType? {
        switch destination {
        case .camera:
            .fullScreenCover
        case .vaultRecovery, .enterMasterPassword, .importVault:
            .push
        case nil:
            nil
        }
    }
    
    func view(for destination: VaultRecoveryScanQRCodeIntroDestination) -> some View {
        switch destination {
        case .camera(let vaultRecoveryData, let onCompletion):
            VaultRecoveryCameraRouter.buildView(recoveryData: vaultRecoveryData, onCompletion: onCompletion)
        case .vaultRecovery(let entropy, let masterKey, let recoveryData):
            VaultRecoveryRecoverRouter.buildView(
                kind: .recoverEncrypted(entropy: entropy, masterKey: masterKey, recoveryData: recoveryData)
            )
        case .importVault(let input, let onClose):
            BackupImportImportingRouter.buildView(input: input, onClose: onClose)
        case .enterMasterPassword(let flowContext, let entropy, let recoveryData):
            VaultRecoveryEnterPasswordRouter.buildView(
                flowContext: flowContext,
                entropy: entropy,
                recoveryData: recoveryData
            )
        }
    }
}
