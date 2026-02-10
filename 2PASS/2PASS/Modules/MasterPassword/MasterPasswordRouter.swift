// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct MasterPasswordRouter: Router {
    
    @ViewBuilder
    static func buildView(
        kind: MasterPasswordKind,
        onFinish: @escaping Callback,
        onClose: @escaping (() -> Void)
    )
    -> some View {
        let interactor: MasterPasswordModuleInteracting = {
            switch kind {
            case .onboarding, .unencryptedVaultRecovery:
                ModuleInteractorFactory.shared.masterPasswordInteractor(setupEncryption: true)
            case .change:
                ModuleInteractorFactory.shared.changeMasterPasswordInteractor()
            }
        }()

        let presenter = MasterPasswordPresenter(
            interactor: interactor,
            kind: kind,
            onFinish: onFinish,
            onClose: onClose
        )

        MasterPasswordView(presenter: presenter)
    }
    
    @ViewBuilder
    func view(for destination: MasterPasswordDestination) -> some View {
        switch destination {
        case .onboardingRecoveryKit:
            VaultDecryptionKitRouter.buildView(kind: .onboarding)
        case .confirmChange(let onConfirm):
            ChangePasswordConfirmView(onConfirm: onConfirm)
        case .changeSuccess(let onFinish):
            ChangeSuccessRouter.buildView(onFinish: onFinish)
        case .vaultDecryptionKit(let onLogin):
            VaultDecryptionKitRouter.buildView(kind: .settings, onFinish: onLogin)
        case .restoreVault(let items, let tags, let onTryAgain):
            VaultRecoveryRecoverRouter.buildView(
                kind: .importUnencrypted(items: items, tags: tags),
                onTryAgain: onTryAgain
            )
        }
    }
    
    func routingType(for destination: MasterPasswordDestination?) -> RoutingType? {
        switch destination {
        case .vaultDecryptionKit, .restoreVault, .changeSuccess: .push
        case .onboardingRecoveryKit: .slidePush
        case .confirmChange: .sheet
        case nil: nil
        }
    }
}
