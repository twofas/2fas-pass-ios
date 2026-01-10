// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct QuickSetupRouter: Router {
    
    static func buildView() -> some View {
        NavigationStack {
            QuickSetupView(presenter: .init(interactor: ModuleInteractorFactory.shared.quickSetupModuleInteractor()))
        }
    }
    
    func routingType(for destination: QuickSetupDestination?) -> RoutingType? {
        switch destination {
        case .defaultSecurityTier:
            return .push
        case .importExport, .transferItems, .syncNotAllowed:
            return .sheet
        case nil:
            return nil
        }
    }
    
    func view(for destination: QuickSetupDestination) -> some View {
        switch destination {
        case .defaultSecurityTier:
            DefaultSecurityTierRouter.buildView()
        case .importExport(let onClose):
            NavigationStack {
                BackupRouter.buildView(flowContext: .quickSetup(onClose: onClose))
            }
            .tint(.accentColor)
        case .transferItems(let onClose):
            NavigationStack {
                TransferItemsServicesListRouter.buildView(flowContext: .quickSetup(onClose: onClose))
            }
            .tint(.accentColor)
        case .syncNotAllowed:
            PremiumPromptRouter.buildView(
                title: Text(.syncErrorIcloudSyncNotAllowedTitle),
                description: Text(.syncErrorIcloudSyncNotAllowedDescription)
            )
        }
    }
}
