// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct TransferItemsServicesListRouter: Router {
    
    static func buildView(flowContext: TransferItemsFlowContext) -> some View {
        TransferItemsServicesListView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.transferItemsServicesListInteractor(),
            flowContext: flowContext
        ))
    }
    
    func routingType(for destination: TransferItemsServicesListDestination?) -> RoutingType? {
        switch destination {
        case .upgradePlanPrompt:
            .sheet
        case .transferInstructions:
            .push
        case nil:
            nil
        }
    }
    
    func view(for destination: TransferItemsServicesListDestination) -> some View {
        switch destination {
        case .transferInstructions(let externalService, let onClose):
            TransferItemsInstructionsRouter.buildView(for: externalService, onClose: onClose)
        case .upgradePlanPrompt(let itemsLimit):
            PremiumPromptRouter.buildView(
                title: Text(.paywallNoticeItemsLimitTransferTitle),
                description: Text(.paywallNoticeItemsLimitTransferMsg(Int32(itemsLimit)))
            )
        }
    }
}
