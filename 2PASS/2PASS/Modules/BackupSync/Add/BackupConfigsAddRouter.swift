// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigsAddRouter: Router {

    let transitionNamespace: Namespace.ID?

    static let webDAVSourceID = "backupConfigs.add.webDAV"
    static let s3SourceID = "backupConfigs.add.s3"

    @MainActor
    static func buildView(onClose: @escaping @MainActor (BackupConfig.ID?) -> Void) -> some View {
        BackupConfigsAddView(
            presenter: BackupConfigsAddPresenter(
                interactor: ModuleInteractorFactory.shared.backupConfigsAddModuleInteractor(),
                onClose: onClose
            )
        )
    }

    func routingType(for destination: BackupConfigsAddDestination?) -> RoutingType? {
        switch destination {
        case .webDAV, .s3:
            .push
        case nil:
            nil
        }
    }

    @ViewBuilder
    func view(for destination: BackupConfigsAddDestination) -> some View {
        switch destination {
        case .webDAV(let onClose):
            BackupWebDAVConfigEditorRouter.buildView(configID: nil, onClose: onClose)
                .matchedZoomDestination(id: Self.webDAVSourceID, in: transitionNamespace)

        case .s3(let onClose):
            BackupS3ConfigEditorRouter.buildView(configID: nil, onClose: onClose)
                .matchedZoomDestination(id: Self.s3SourceID, in: transitionNamespace)
        }
    }
}
