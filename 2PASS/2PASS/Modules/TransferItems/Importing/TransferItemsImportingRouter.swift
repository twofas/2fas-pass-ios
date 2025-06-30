// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct TransferItemsImportingRouter {
    
    @MainActor
    static func buildView(service: ExternalService, passwords: [PasswordData], onClose: @escaping Callback) -> some View {
        TransferItemsImportingView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.transferItemsImportingModuleInteractor(
                service: service,
                passwords: passwords
            ),
            onClose: onClose
        ))
    }
}
