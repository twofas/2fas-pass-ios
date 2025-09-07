// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common

enum TransferItemsFileSummaryDestination: RouterDestination {
    case importItems([ItemData], service: ExternalService, onClose: Callback)
    
    var id: String {
        switch self {
        case .importItems: "importItems"
        }
    }
}

@Observable
final class TransferItemsFileSummaryPresenter {
    
    let service: ExternalService
    let items: [ItemData]
    
    var destination: TransferItemsFileSummaryDestination?
    
    private let onClose: Callback
    
    init(service: ExternalService, items: [ItemData], onClose: @escaping Callback) {
        self.service = service
        self.items = items
        self.onClose = onClose
    }
    
    func onProceed() {
        destination = .importItems(items, service: service, onClose: onClose)
    }
}
