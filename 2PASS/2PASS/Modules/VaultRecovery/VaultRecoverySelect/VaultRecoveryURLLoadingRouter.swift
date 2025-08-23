// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct VaultRecoveryURLLoadingRouter {
    
    static func buildView(url: URL, onClose: @escaping Callback) -> some View {
        VaultRecoveryURLLoadingView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryCheckModuleInteractor(url: url),
            onClose: onClose
        ))
    }
}
