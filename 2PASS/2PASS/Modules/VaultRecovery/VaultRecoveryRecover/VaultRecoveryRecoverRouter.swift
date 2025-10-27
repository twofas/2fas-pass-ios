// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data
import CommonUI

enum VaultRecoveryRecoverKind {
    case importUnencrypted(items: [ItemData], tags: [ItemTagData])
    case recoverEncrypted(
        entropy: Entropy,
        masterKey: MasterKey,
        recoveryData: VaultRecoveryData
    )
}

struct VaultRecoveryRecoverRouter {
    
    @ViewBuilder
    static func buildView(kind: VaultRecoveryRecoverKind)
    -> some View {
        let presenter = VaultRecoveryRecoverPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryRecoverModuleInteractor(kind: kind)
        )
        VaultRecoveryRecoverView(presenter: presenter)
    }
}
