// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct RestoreVaultRouter {
    
    static func buildView(onClose: @escaping Callback) -> some View {
        NavigationStack {
            RestoreVaultView(presenter: .init(
                flowContext: .restoreVault,
                interactor: ModuleInteractorFactory.shared.vaultRecoverySelectModuleInteractor(),
                recoveryData: .localVault
            ))
        }
        .environment(\.dismissFlow, DismissFlowAction(action: {
            onClose()
        }))
    }
}
