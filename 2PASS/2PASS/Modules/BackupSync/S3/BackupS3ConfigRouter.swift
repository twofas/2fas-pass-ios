// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupS3ConfigRouter: Router {

    @MainActor
    static func buildView(configID: UUID?) -> some View {
        BackupS3ConfigContainerView(configID: configID)
    }

    func routingType(for destination: BackupS3ConfigDestination?) -> RoutingType? {
        nil
    }

    @ViewBuilder
    func view(for destination: BackupS3ConfigDestination) -> some View {
        EmptyView()
    }
}

private struct BackupS3ConfigContainerView: View {
    let configID: UUID?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            BackupS3ConfigView(
                presenter: .init(
                    interactor: ModuleInteractorFactory.shared.backupS3ConfigModuleInteractor(configID: configID),
                    configID: configID,
                    onClose: { dismiss() }
                )
            )
        }
    }
}
