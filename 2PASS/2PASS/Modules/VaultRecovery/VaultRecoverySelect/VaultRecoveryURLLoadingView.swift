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
            // File-picker entry: no transport credentials to persist. `.localFile` is the
            // explicit "user opened a file directly" marker — `persistRecoverySource` no-ops
            // for this case.
            VaultRecoverySelectRouter.buildView(flowContext: .onboarding(onClose: presenter.onClose), recoveryData: .file(fileData, source: .localFile))
        default:
            VaultRecoveryCheckView(presenter: presenter)
        }
    }
}
