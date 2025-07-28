// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryiCloudVaultSelectionRouter: Router {
    
    @ViewBuilder
    static func buildView(onSelect: @escaping (VaultRecoveryData) -> Void) -> some View {
        let presenter = VaultRecoveryiCloudVaultSelectionPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryiCloudVaultSelectionModuleInteractor(),
            onSelect: onSelect
        )
        
        NavigationStack {
            VaultRecoveryiCloudVaultSelectionView(presenter: presenter)
        }
    }
    
    func routingType(for destination: VaultRecoveryiCloudVaultSelectionDestination?) -> RoutingType? {
        switch destination {
        case .confirmDeletion:
            return .alert(title: T.cloudVaultDeleteConfirmTitle, message: T.cloudVaultDeleteConfirmBody)
        case nil:
            return nil
        }
    }
    
    func view(for destination: VaultRecoveryiCloudVaultSelectionDestination) -> some View {
        switch destination {
        case .confirmDeletion(let onConfirm):
            Button(T.knownBrowserDeleteButton.localizedKey, role: .destructive, action: onConfirm)
            Button(T.commonCancel.localizedKey, role: .cancel, action: {})
        }
    }
}
