// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public enum SubscriptionPlanType: String, CaseIterable {
    case free
    case premium
}

public struct SubscriptionPlan {
    public let planType: SubscriptionPlanType
    public let paymentInfo: PaymentInfo?
    
    public init(planType: SubscriptionPlanType, paymentInfo: PaymentInfo?) {
        self.planType = planType
        self.paymentInfo = paymentInfo
    }
    
    public var entitlements: Entitlements {
        switch planType {
        case .free: Config.Payment.freeEntitlements
        case .premium: Config.Payment.premiumEntitlements
        }
    }
    
    public var expirationDate: Date? {
        paymentInfo?.expirationDate
    }
}

extension SubscriptionPlan {
    
    public static let free = SubscriptionPlan(planType: .free, paymentInfo: nil)
}

extension SubscriptionPlan {
    
    public struct PaymentInfo {
        public let expirationDate: Date?
        public let willRenew: Bool
        
        public init(expirationDate: Date?, willRenew: Bool) {
            self.expirationDate = expirationDate
            self.willRenew = willRenew
        }
    }
    
    public struct Entitlements {
        public let itemsLimit: Int?
        public let connectedBrowsersLimit: Int?
        public let multiDeviceSync: Bool
    }
}
