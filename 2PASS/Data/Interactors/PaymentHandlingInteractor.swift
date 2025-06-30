// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol PaymentHandlingInteracting: AnyObject {
    func initialize()
}

final class PaymentHandlingInteractor {
    private let mainRepository: MainRepository
    private var isInitialized = false
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension PaymentHandlingInteractor: PaymentHandlingInteracting {
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        
        mainRepository.paymentInitialize(apiKey: Config.Payment.apiKey, debug: false)
        mainRepository.paymentUpdatePaymentStatus(subscriptionName: Config.Payment.subscriptionId)
        mainRepository.paymentRegisterForUserUpdate { [weak self] in
            self?.mainRepository.paymentUpdatePaymentStatus(subscriptionName: Config.Payment.subscriptionId)
        }
        mainRepository.paymentRegisterForPromotedPurchase { true }
    }
}
