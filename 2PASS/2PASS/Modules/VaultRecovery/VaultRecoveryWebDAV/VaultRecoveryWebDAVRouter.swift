// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct VaultRecoveryWebDAVRouter: Router {

    @MainActor
    @ViewBuilder
    static func buildView(
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) -> some View {
        let presenter = VaultRecoveryWebDAVPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryWebDAVModuleInteractor(),
            onSelect: onSelect
        )

        NavigationStack {
            VaultRecoveryWebDAVView(presenter: presenter)
        }
    }

    @ViewBuilder
    func view(for destination: VaultRecoveryWebDAVDestination) -> some View {
        switch destination {
        case .errorAlert:
            EmptyView()
        case .selectVault(let index, let baseURL, let allowTLSOff, let login, let password, let onSelect):
            VaultRecoverySelectWebDAVIndexRouter.buildView(
                index: index,
                baseURL: baseURL,
                allowTLSOff: allowTLSOff,
                login: login,
                password: password,
                onSelect: onSelect
            )
        }
    }

    func routingType(for destination: VaultRecoveryWebDAVDestination?) -> RoutingType? {
        switch destination {
        case .selectVault: .push
        case .errorAlert(let message): .alert(title: String(localized: .commonError), message: message)
        case nil: nil
        }
    }
}
