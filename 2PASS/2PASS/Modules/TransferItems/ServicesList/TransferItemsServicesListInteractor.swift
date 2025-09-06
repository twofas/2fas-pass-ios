// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol TransferItemsServicesListInteracting: AnyObject {
    var currentPlanItemsLimit: Int { get }
    var canTransfer: Bool { get }
}

final class TransferItemsServicesListInteractor: TransferItemsServicesListInteracting {
    
    let passwordInteractor: PasswordInteracting
    let paymentStatusInteractor: PaymentStatusInteracting
    
    init(passwordInteractor: PasswordInteracting, paymentStatusInteractor: PaymentStatusInteracting) {
        self.passwordInteractor = passwordInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
    }
    
    var canTransfer: Bool {
        guard let limit = paymentStatusInteractor.entitlements.itemsLimit else {
            return true
        }
        return passwordInteractor.itemsCount < limit
    }
    
    var currentPlanItemsLimit: Int {
        paymentStatusInteractor.entitlements.itemsLimit ?? Int.max
    }
}
