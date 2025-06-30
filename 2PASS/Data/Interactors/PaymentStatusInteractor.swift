// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol PaymentStatusInteracting: AnyObject {
    var userId: String? { get }
    var isPremium: Bool { get }
    var entitlements: SubscriptionPlan.Entitlements { get }
    var plan: SubscriptionPlan { get }
    
    func fetchRenewPrice() async -> String?
}

final class PaymentStatusInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension PaymentStatusInteractor: PaymentStatusInteracting {
    
    var userId: String? {
        mainRepository.paymentUserId
    }
    
    var isPremium: Bool {
        mainRepository.paymentSubscriptionPlan.planType == .premium
    }
    
    var plan: SubscriptionPlan {
        mainRepository.paymentSubscriptionPlan
    }
    
    var entitlements: SubscriptionPlan.Entitlements {
        mainRepository.paymentSubscriptionPlan.entitlements
    }
    
    func fetchRenewPrice() async -> String? {
        await mainRepository.paymentSubscriptionPrice(subscriptionName: Config.Payment.subscriptionId)
    }
}
