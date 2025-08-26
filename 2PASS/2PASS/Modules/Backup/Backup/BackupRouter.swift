// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct BackupRouter: Router {
    
    static func buildView(flowContext: BackupFlowContext) -> some View {
        BackupView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.backupModuleInteractor(),
            flowContext: flowContext
        ))
    }
    
    func routingType(for destination: BackupDestination?) -> RoutingType? {
        switch destination {
        case .importFile(let onClose):
            .fileImporter(contentTypes: .vaultFiles, onClose: onClose)
        case .currentPassword, .upgradePlanPrompt:
            .sheet
        case .export, .recoveryEnterPassword, .importing, .importingFailure, .recovery:
            .push
        case nil:
            nil
        }
    }
    
    func view(for destination: BackupDestination) -> some View {
        switch destination {
        case .importingFailure(let onClose):
            BackupImportFailureView(onClose: onClose)
        case .importing(let input, let onClose):
            BackupImportImportingRouter.buildView(input: input, onClose: onClose)
        case .recoveryEnterPassword(let vault, let entropy, let onClose):
            VaultRecoveryEnterPasswordRouter.buildView(flowContext: .importVault(onClose: onClose), entropy: entropy, recoveryData: .file(vault))
        case .recovery(let vault, let onClose):
            VaultRecoverySelectRouter.buildView(flowContext: .importVault(onClose: onClose), recoveryData: .file(vault))
        case .importFile:
            EmptyView()
        case .currentPassword(let config, let onSuccess):
            LoginView(presenter: .init(
                loginSuccessful: onSuccess,
                interactor: ModuleInteractorFactory.shared.loginModuleInteractor(
                    config: config
                )
            ))
        case .export(let onClose):
            BackupExportFileRouter.buildView(onClose: onClose)
        case .upgradePlanPrompt(let itemsLimit):
            PremiumPromptRouter.buildView(
                title: Text(T.paywallNoticeItemsLimitImportTitle.localizedKey),
                description: Text(T.paywallNoticeItemsLimitImportMsg(itemsLimit))
            )
        }
    }
}
