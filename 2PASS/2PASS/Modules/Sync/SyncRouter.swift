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
            .alert(title: T.generalNotAvailable, message: reason)
        case .iCloudSchemeNotSupported(let schemeVersion, _):
            .alert(title: T.appUpdateModalTitle, message: T.cloudSyncInvalidSchemaErrorMsg(schemeVersion))
        case .disableWebDAVConfirmation:
            .alert(title: T.webdavDisableIcloudConfirmTitle, message: T.webdavDisableWebdavConfirmBody)
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
            Button(T.commonOk.localizedKey) {}
        case .iCloudSchemeNotSupported(_, let onUpdateApp):
            Button(T.appUpdateModalCtaNegative.localizedKey, role: .cancel) {}
            Button(T.appUpdateModalCtaPositive.localizedKey, action: onUpdateApp)
        case .disableWebDAVConfirmation(onConfirm: let onConfirm):
            Button(T.commonCancel.localizedKey, role: .cancel) {}
            Button(T.commonConfirm.localizedKey, role: .destructive, action: onConfirm)
        case .syncNotAllowed:
            PremiumPromptRouter.buildView(
                title: Text(T.syncErrorIcloudSyncNotAllowedTitle.localizedKey),
                description: Text(T.syncErrorIcloudSyncNotAllowedDescription.localizedKey)
            )
        }
    }
}
