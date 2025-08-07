// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import SwiftUI

struct SettingsRouter: Router {

    static func buildView() -> some View {
        SettingsView(presenter: .init(interactor: ModuleInteractorFactory.shared.settingsInteractor()))
    }
    
    func routingType(for destination: SettingsDestination?) -> RoutingType? {
        .push
    }
    
    @ViewBuilder
    func view(for destination: SettingsDestination) -> some View {
        switch destination {
        case .security:
            AppSecurityRouter.buildView()
        case .customization:
            CustomizationRouter.buildView()
        case .autoFill:
            AutofillSettingsRouter.buildView()
        case .deletedData:
            TrashRouter.buildView()
        case .knownWebBrowsers:
            KnownBrowsersRouter.buildView()
        case .pushNotifications:
            PushNotificationsRouter.buildView()
        case .about:
            AboutRouter.buildView()
        case .sync:
            SyncRouter.buildView()
        case .debug:
            SettingsDebugRouter.buildView()
        case .importExport:
            BackupRouter.buildView(flowContext: .settings)
        case .transferItems:
            TransferItemsServicesListRouter.buildView(flowContext: .settings)
        case .manageSubscription:
            ManageSubscriptionRouter.buildView()
        default:
            EmptyView()
        }
    }
}
