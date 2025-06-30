// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryiCloudVaultSelectionRouter {
    
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
}
