// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct AppSecurityRouter: Router {
    
    @MainActor
    static func buildView() -> some View {
        AppSecurityView(presenter: .init(interactor: ModuleInteractorFactory.shared.appSecurityModuleInteractor()))
    }
    
    func routingType(for destination: AppSecurityRouteDestination?) -> RoutingType? {
        switch destination {
        case .changePassword, .limitOfFailedAttempts, .defaultSecurityTier, .vaultDecryptionKit:
            .push
        case .currentPassword:
            .sheet
        case nil:
            .none
        }
    }
    
    @ViewBuilder
    func view(for destination: AppSecurityRouteDestination) -> some View {
        switch destination {
        case .changePassword(let onResult):
            MasterPasswordRouter.buildView(kind: .change, onFinish: {
                onResult(.success(()))
            }, onClose: {})
            
        case .limitOfFailedAttempts(let picker):
            SettingsPickerView(
                title: Text(T.settingsEntryAppLockAttempts.localizedKey),
                footer: Text(T.settingsEntryAppLockAttemptsDescription.localizedKey),
                picker: picker
            )
            
        case .currentPassword(let config, let onSuccess):
            LoginRouter.buildView(config: config, onSuccess: onSuccess)

        case .defaultSecurityTier:
            DefaultSecurityTierRouter.buildView()
        case .vaultDecryptionKit(let onFinish):
            VaultDecryptionKitRouter.buildView(kind: .settings, onFinish: onFinish)
        }
    }
}
