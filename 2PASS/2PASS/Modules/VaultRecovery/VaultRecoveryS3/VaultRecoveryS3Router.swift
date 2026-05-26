// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UniformTypeIdentifiers
import Common
import CommonUI

struct VaultRecoveryS3Router: Router {

    @MainActor
    @ViewBuilder
    static func buildView(
        onSelect: @escaping (VaultRecoveryData) -> Void
    ) -> some View {
        let presenter = VaultRecoveryS3Presenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoveryS3ModuleInteractor(),
            onSelect: onSelect
        )

        NavigationStack {
            VaultRecoveryS3View(presenter: presenter)
        }
    }

    @ViewBuilder
    func view(for destination: VaultRecoveryS3Destination) -> some View {
        switch destination {
        case .errorAlert:
            EmptyView()
        case .loadFromCSV:
            EmptyView()
        case .selectVault(let index, let config, let onSelect):
            VaultRecoverySelectS3IndexRouter.buildView(
                index: index,
                config: config,
                onSelect: onSelect
            )
        }
    }

    func routingType(for destination: VaultRecoveryS3Destination?) -> RoutingType? {
        switch destination {
        case .selectVault: .push
        case .errorAlert(let message): .alert(title: String(localized: .commonError), message: message)
        case .loadFromCSV(let onClose): .fileImporter(contentTypes: [.commaSeparatedText], onClose: onClose)
        case nil: nil
        }
    }
}
