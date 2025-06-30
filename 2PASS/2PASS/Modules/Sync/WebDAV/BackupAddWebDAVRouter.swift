// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupAddWebDAVRouter: Router {
    
    static func buildView() -> some View {
        BackupAddWebDAVView(
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.backupAddWebDAVModuleInteractor()
            )
        )
    }
    
    func routingType(for destination: BackupAddWebDAVRouteDestination?) -> RoutingType? {
        switch destination {
        case .disableCloudSyncConfirmation:
            return .alert(title: T.webdavDisableIcloudConfirmTitle.localized, message: T.webdavDisableIcloudConfirmBody.localized)
        case .upgradePlanPrompt:
             return .sheet
        default:
            return nil
        }
    }
    
    func view(for destination: BackupAddWebDAVRouteDestination) -> some View {
        switch destination {
        case .disableCloudSyncConfirmation(let onConfirm):
            Button(T.commonCancel.localizedKey, role: .cancel) {}
            Button(T.commonConfirm.localizedKey, role: .destructive, action: onConfirm)
        case .upgradePlanPrompt:
            PremiumPromptRouter.buildView(
                title: Text(T.paywallNoticeBrowsersLimitTitle.localizedKey),
                description: Text(T.paywallNoticeBrowsersLimitMsg.localizedKey)
            )
        }
    }
}
