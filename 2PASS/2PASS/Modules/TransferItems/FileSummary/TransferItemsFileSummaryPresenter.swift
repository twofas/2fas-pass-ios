// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common

enum TransferItemsFileSummaryDestination: RouterDestination {
    case importPasswords([ItemData], service: ExternalService, onClose: Callback)
    
    var id: String {
        switch self {
        case .importPasswords: "importPasswords"
        }
    }
}

@Observable
final class TransferItemsFileSummaryPresenter {
    
    let service: ExternalService
    let passwords: [ItemData]
    
    var destination: TransferItemsFileSummaryDestination?
    
    private let onClose: Callback
    
    init(service: ExternalService, passwords: [ItemData], onClose: @escaping Callback) {
        self.service = service
        self.passwords = passwords
        self.onClose = onClose
    }
    
    func onProceed() {
        destination = .importPasswords(passwords, service: service, onClose: onClose)
    }
}
