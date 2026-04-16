// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

struct TransferItemsImportingRouter {

    @MainActor
    static func buildView(service: ExternalService, result: ExternalServiceImportResult, targetVaultID: VaultID, onClose: @escaping Callback) -> some View {
        TransferItemsImportingView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.transferItemsImportingModuleInteractor(
                service: service,
                result: result,
                targetVaultID: targetVaultID
            ),
            onClose: onClose
        ))
    }
}
