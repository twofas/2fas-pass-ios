// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupWebDAVConfigRouter: Router {

    @MainActor
    static func buildView(configID: UUID?) -> some View {
        BackupWebDAVConfigContainerView(configID: configID)
    }

    func routingType(for destination: BackupWebDAVConfigDestination?) -> RoutingType? {
        nil
    }

    @ViewBuilder
    func view(for destination: BackupWebDAVConfigDestination) -> some View {
        EmptyView()
    }
}

private struct BackupWebDAVConfigContainerView: View {
    let configID: UUID?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BackupWebDAVConfigView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.backupWebDAVConfigModuleInteractor(configID: configID),
                configID: configID,
                onClose: { _ in dismiss() }
            )
        )
    }
}
