// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

enum TransferItemsServicesListDestination: Identifiable {
    case transferInstructions(ExternalService, onClose: Callback)
    case upgradePlanPrompt(itemsLimit: Int)
    
    var id: String {
        switch self {
        case .transferInstructions(let service, _):
            "transferInstructions_\(service.name)"
        case .upgradePlanPrompt:
            "upgradePlanPrompt"
        }
    }
}

@Observable
final class TransferItemsServicesListPresenter {
    
    var destination: TransferItemsServicesListDestination?
    
    private let interactor: TransferItemsServicesListInteracting
    
    init(interactor: TransferItemsServicesListInteracting) {
        self.interactor = interactor
    }
    
    func onSelect(_ service: ExternalService) {
        guard interactor.canTransfer else {
            destination = .upgradePlanPrompt(itemsLimit: interactor.currentPlanItemsLimit)
            return
        }
        
        destination = .transferInstructions(service, onClose: { [weak self] in
            self?.destination = nil
        })
    }
}
