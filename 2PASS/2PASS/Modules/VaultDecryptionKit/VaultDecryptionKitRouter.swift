// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

enum VaultDecryptionKitKind {
    case onboarding
    case settings
}

struct VaultDecryptionKitRouter: Router {

    @ViewBuilder
    static func buildView(kind: VaultDecryptionKitKind, onFinish: @escaping () -> Void = {}) -> some View {
        let interactor: RecoveryKitModuleInteracting = {
            switch kind {
            case .onboarding:
                ModuleInteractorFactory.shared.recoveryKitOnboardingModuleInteractor()
            case .settings:
                ModuleInteractorFactory.shared.recoveryKitSettingsModuleInteractor()
            }
        }()
        
        VaultDecryptionKitView(presenter: VaultDecryptionKitPresenter(
            kind: kind,
            interactor: interactor,
            onFinish: onFinish
        ))
    }
    
    func routingType(for destination: VaultDecryptionKitDestination?) -> RoutingType? {
        switch destination {
        case .shareSheet:
            return .sheet
        case .setupComplete:
            return .slidePush
        case .settings:
            return .sheet
        case .none:
            return nil
        }
    }
    
    @ViewBuilder
    func view(for destination: VaultDecryptionKitDestination) -> some View {
        switch destination {
        case .settings(let includeMasterKey):
            VaultDescryptionKitSettingsView(includeMasterKey: includeMasterKey)
        case .shareSheet(url: let url, complete: let complete, error: let error):
            ShareSheetView(
                title: T.decryptionKeyShareSheetTitle,
                url: url,
                activityComplete: complete,
                activityError: error
            )
        case .setupComplete:
            SetupCompleteRouter.buildView()
        }
    }
}
