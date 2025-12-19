// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

struct TransferItemsFileSummaryRouter: Router {

    static func buildView(service: ExternalService, result: ExternalServiceImportResult, onClose: @escaping Callback) -> some View {
        TransferItemsFileSummaryView(presenter: .init(service: service, result: result, onClose: onClose))
    }

    func routingType(for destination: TransferItemsFileSummaryDestination?) -> RoutingType? {
        switch destination {
        case .importItems:
            .push
        case nil:
            nil
        }
    }

    func view(for destination: TransferItemsFileSummaryDestination) -> some View {
        switch destination {
        case .importItems(let result, let service, let onClose):
            TransferItemsImportingRouter.buildView(service: service, result: result, onClose: onClose)
        }
    }
}
