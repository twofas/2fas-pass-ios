// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

struct TransferItemsFlowContext {
    
    typealias ResultCallback = Callback
    
    enum Kind {
        case quickSetup
        case settings
    }
    
    let kind: Kind
    let onClose: ResultCallback?
    
    static var settings: Self {
        .init(kind: .settings)
    }
    
    static func quickSetup(onClose: @escaping ResultCallback) -> Self {
        .init(kind: .quickSetup, onClose: onClose)
    }
    
    private init(kind: Kind, onClose: ResultCallback? = nil) {
        self.kind = kind
        self.onClose = onClose
    }
}

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
    
    let flowContext: TransferItemsFlowContext
    private let interactor: TransferItemsServicesListInteracting
    
    init(interactor: TransferItemsServicesListInteracting, flowContext: TransferItemsFlowContext) {
        self.interactor = interactor
        self.flowContext = flowContext
    }
    
    func onSelect(_ service: ExternalService) {
        guard interactor.canTransfer else {
            destination = .upgradePlanPrompt(itemsLimit: interactor.currentPlanItemsLimit)
            return
        }
        
        destination = .transferInstructions(service, onClose: { [weak self] in
            self?.close()
        })
    }
    
    private func close() {
        switch flowContext.kind {
        case .quickSetup:
            flowContext.onClose?()
        case .settings:
            destination = nil
        }
    }
}
