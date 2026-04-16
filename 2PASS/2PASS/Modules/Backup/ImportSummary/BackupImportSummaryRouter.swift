// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

struct BackupImportSummaryRouter: Router {

    @MainActor
    static func buildView(input: BackupImportInput, onClose: @escaping Callback) -> some View {
        BackupImportSummaryView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.backupImportSummaryModuleInteractor(),
            input: input,
            onClose: onClose
        ))
    }

    func routingType(for destination: BackupImportSummaryDestination?) -> RoutingType? {
        switch destination {
        case .importing:
            .push
        case nil:
            nil
        }
    }

    func view(for destination: BackupImportSummaryDestination) -> some View {
        switch destination {
        case .importing(let input, let targetVaultID, let onClose):
            BackupImportImportingRouter.buildView(input: input, targetVaultID: targetVaultID, onClose: onClose)
        }
    }
}
