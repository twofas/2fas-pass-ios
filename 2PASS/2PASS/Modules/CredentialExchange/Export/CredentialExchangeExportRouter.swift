// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

@available(iOS 26.0, *)
struct CredentialExchangeExportRouter: Router {

    @MainActor static func buildView(onClose: @escaping Callback) -> some View {
        let interactor = ModuleInteractorFactory.shared.credentialExchangeExportModuleInteractor()
        let presenter = CredentialExchangeExportPresenter(
            interactor: interactor,
            onClose: onClose
        )
        return CredentialExchangeExportView(presenter: presenter)
    }

    func routingType(for destination: CredentialExchangeExportDestination?) -> RoutingType? {
        switch destination {
        case .error: .push
        case nil: nil
        }
    }

    func view(for destination: CredentialExchangeExportDestination) -> some View {
        switch destination {
        case .error(let onClose):
            ResultView(
                kind: .failure,
                title: Text(.credentialExchangeExportErrorTitle),
                description: Text(.credentialExchangeExportIdleDescription)
            ) {
                Button(.commonClose) {
                    onClose()
                }
            }
        }
    }
}
