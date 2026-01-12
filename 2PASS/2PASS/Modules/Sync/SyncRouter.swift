// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct SyncRouter: Router {
    
    @MainActor
    static func buildView() -> some View {
        SyncView(presenter: .init(interactor: ModuleInteractorFactory.shared.syncModuleInteractor()))
    }
    
    func routingType(for destination: SyncDestination?) -> RoutingType? {
        switch destination {
        case .webDAV:
            .push
        case .iCloudNotAvailable(let reason):
            .alert(title: String(localized: .generalNotAvailable), message: reason)
        case .iCloudSchemeNotSupported(let schemeVersion, _):
            .alert(title: String(localized: .appUpdateModalTitle), message: String(localized: .cloudSyncInvalidSchemaErrorMsg(Int32(schemeVersion))))
        case .disableWebDAVConfirmation:
            .alert(title: String(localized: .webdavDisableIcloudConfirmTitle), message: String(localized: .webdavDisableWebdavConfirmBody))
        case .syncNotAllowed:
            .sheet
        case nil:
            nil
        }
    }
    
    func view(for destination: SyncDestination) -> some View {
        switch destination {
        case .webDAV:
            BackupAddWebDAVRouter.buildView()
        case .iCloudNotAvailable:
            Button(.commonOk) {}
        case .iCloudSchemeNotSupported(_, let onUpdateApp):
            Button(.appUpdateModalCtaNegative, role: .cancel) {}
            Button(.appUpdateModalCtaPositive, action: onUpdateApp)
        case .disableWebDAVConfirmation(onConfirm: let onConfirm):
            Button(.commonCancel, role: .cancel) {}
            Button(.commonConfirm, role: .destructive, action: onConfirm)
        case .syncNotAllowed:
            PremiumPromptRouter.buildView(
                title: Text(.syncErrorIcloudSyncNotAllowedTitle),
                description: Text(.syncErrorIcloudSyncNotAllowedDescription)
            )
        }
    }
}
