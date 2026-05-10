// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data
import Backup
import CommonUI

struct VaultRecoverySelectS3IndexRouter: Router {

    @ViewBuilder
    static func buildView(
        index: BackupIndex,
        config: S3ServiceConfig,
        onSelect: @escaping (ExchangeVaultVersioned, VaultRecoveryFileSource) -> Void
    )
    -> some View {
        let presenter = VaultRecoverySelectS3IndexPresenter(
            interactor: ModuleInteractorFactory.shared.vaultRecoverySelectS3IndexModuleInteractor(),
            index: index,
            config: config,
            onSelect: onSelect
        )

        // No NavigationStack here: this view is pushed inside the S3 form's stack.
        VaultRecoverySelectS3IndexView(presenter: presenter)
    }

    @ViewBuilder
    func view(for destination: VaultRecoverySelectS3IndexDestination) -> some View {
        switch destination {
        case .error(_, let onClose):
            Button(.commonOk, action: onClose)
        case .selectRecoveryKey(let vault, let onClose):
            // Mirrors the WebDAV nested-router branch: this leg is reached only when the
            // recovery flow has already been routed through the parent `VaultRecoveryS3Presenter`,
            // which carries the source config forward via `.select(.file(vault, source:))`.
            // `.localFile` here marks "no transport credentials to persist" for this branch.
            VaultRecoverySelectRouter.buildView(flowContext: .onboarding(onClose: onClose), recoveryData: .file(vault, source: .localFile))
        case .appUpdateNeeded(_, let onUpdate, let onClose):
            Button(.importInvalidSchemaErrorCta, action: onUpdate)
            Button(.commonCancel, role: .cancel, action: onClose)
        }
    }

    func routingType(for destination: VaultRecoverySelectS3IndexDestination?) -> RoutingType? {
        switch destination {
        case .selectRecoveryKey: .push
        case .error(let message, _): .alert(title: String(localized: .commonError), message: message)
        case .appUpdateNeeded(let schemaVersion, _, _):
            .alert(
                title: String(localized: .commonError),
                message: String(localized: .importInvalidSchemaErrorMsg(Int32(schemaVersion)))
            )
        case nil: nil
        }
    }
}
