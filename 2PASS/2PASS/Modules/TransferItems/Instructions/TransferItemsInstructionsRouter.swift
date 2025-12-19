// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

struct TransferItemsInstructionsRouter: Router {
    
    static func buildView(for externalService: ExternalService, onClose: @escaping Callback) -> some View {
        TransferItemsInstructionsView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.transferItemsInstructionsModuleInteractor(
                service: externalService
            ),
            onClose: onClose
        ))
    }
    
    func view(for destination: TransferItemsInstructionsDestination) -> some View {
        switch destination {
        case .uploadFile:
            EmptyView()
        case .summary(let service, let result, let onClose):
            TransferItemsFileSummaryRouter.buildView(service: service, result: result, onClose: onClose)
        case .importFailure(let onClose):
            TransferItemsFailureView(onClose: onClose)
        }
    }
    
    func routingType(for destination: TransferItemsInstructionsDestination?) -> RoutingType? {
        switch destination {
        case .uploadFile(let service, let onClose):
            .fileImporter(contentTypes: service.allowedContentTypes, onClose: onClose)
        case .summary, .importFailure:
            .push
        case nil:
            nil
        }
    }
}

