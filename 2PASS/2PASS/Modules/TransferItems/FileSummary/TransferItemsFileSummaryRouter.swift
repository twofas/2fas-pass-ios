// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct TransferItemsFileSummaryRouter: Router {
    
    static func buildView(service: ExternalService, passwords: [ItemData], onClose: @escaping Callback) -> some View {
        TransferItemsFileSummaryView(presenter: .init(service: service, passwords: passwords, onClose: onClose))
    }
    
    func routingType(for destination: TransferItemsFileSummaryDestination?) -> RoutingType? {
        switch destination {
        case .importPasswords:
            .push
        case nil:
            nil
        }
    }
    
    func view(for destination: TransferItemsFileSummaryDestination) -> some View {
        switch destination {
        case .importPasswords(let passwords, let service, let onClose):
            TransferItemsImportingRouter.buildView(service: service, passwords: passwords, onClose: onClose)
        }
    }
}
