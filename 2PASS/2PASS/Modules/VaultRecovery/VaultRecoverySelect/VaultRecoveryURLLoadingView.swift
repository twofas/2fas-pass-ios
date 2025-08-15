// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct VaultRecoveryURLLoadingView: View {
    
    @State
    var presenter: VaultRecoveryCheckPresenter
    
    var body: some View {
        switch presenter.destination {
        case .encrypted(let fileData):
            VaultRecoverySelectRouter.buildView(flowContext: .onboarding(onClose: presenter.onClose), recoveryData: .file(fileData))
        default:
            VaultRecoveryCheckView(presenter: presenter)
        }
    }
}
