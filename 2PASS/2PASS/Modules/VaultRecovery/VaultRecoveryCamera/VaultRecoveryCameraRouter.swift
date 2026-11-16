// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Data

struct VaultRecoveryCameraRouter {

    @MainActor @ViewBuilder
    static func buildView(onScanned: @escaping (Entropy, MasterKey?) -> Void) -> some View {
        let presenter = VaultRecoveryCameraPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryCameraModuleInteractor(),
            onScanned: onScanned
        )
        VaultRecoveryCameraView(presenter: presenter)
    }
}
