// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Common
import CommonUI
import Data
import SwiftUI

@available(iOS 26.0, *)
struct CredentialExchangeImportRouter: Router {

    @MainActor @ViewBuilder
    static func buildView(data: ASExportedCredentialData, onClose: @escaping Callback) -> some View {
        let interactor = ModuleInteractorFactory.shared.credentialExchangeImportModuleInteractor()
        let presenter = CredentialExchangeImportPresenter(
            data: data,
            interactor: interactor,
            onClose: onClose
        )
        
        NavigationStack {
            CredentialExchangeImportView(presenter: presenter)
        }
    }

    func routingType(for destination: CredentialExchangeImportDestination?) -> RoutingType? {
        switch destination {
        case .performImport: .push
        case nil: nil
        }
    }

    @ViewBuilder
    func view(for destination: CredentialExchangeImportDestination) -> some View {
        switch destination {
        case .performImport(let result, let onClose):
            CredentialExchangePerformImportRouter.buildView(
                result: result,
                onClose: onClose
            )
        }
    }
}
