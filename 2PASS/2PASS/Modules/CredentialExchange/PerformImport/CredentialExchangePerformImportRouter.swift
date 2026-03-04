// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import CommonUI
import Data
import SwiftUI

@available(iOS 26.0, *)
struct CredentialExchangePerformImportRouter {

    @MainActor
    static func buildView(
        result: ExternalServiceImportResult,
        onClose: @escaping Callback
    ) -> some View {
        let interactor = ModuleInteractorFactory.shared.credentialExchangePerformImportModuleInteractor()
        let presenter = CredentialExchangePerformImportPresenter(
            result: result,
            interactor: interactor,
            onClose: onClose
        )
        return CredentialExchangePerformImportView(presenter: presenter)
    }
}
