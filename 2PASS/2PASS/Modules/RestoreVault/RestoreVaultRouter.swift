// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct RestoreVaultRouter {
    
    static func buildView(onClose: @escaping Callback) -> some View {
        NavigationStack {
            VaultRecoverySelectRouter.buildView(
                flowContext: .restoreVault,
                recoveryData: .localVault
            )
            .toolbar(.visible, for: .navigationBar)
        }
        .environment(\.dismissFlow, DismissFlowAction(action: {
            onClose()
        }))
    }
}
