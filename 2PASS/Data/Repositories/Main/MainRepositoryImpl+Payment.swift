// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import RevenueCat

extension MainRepositoryImpl {
    var paymentSubscriptionPlan: SubscriptionPlan {
        userDefaultsDataSource.debugSubscriptionPlan ?? _subscriptionPlan
    }
    
    var paymentUserId: String? {
        Purchases.shared.appUserID
    }
        
    func paymentInitialize(apiKey: String, debug: Bool = false) {
        if debug {
            Purchases.logLevel = .debug
        } else {
            Purchases.logLevel = .info
        }
        Purchases.logHandler = { level, message in
            Log("[RevenueCat] \(message, privacy: .public)", severity: level.severity)
        }
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = revenueCatDelegate
    }
    
    func paymentRegisterForUserUpdate(_ callback: @escaping () -> Void) {
        revenueCatDelegate.receivedUpdate = { _ in callback() }
    }
    
    func paymentRegisterForPromotedPurchase(_ callback: @escaping () -> Bool) {
        revenueCatDelegate.readyForPromotedProduct = { [weak self] startPurchaseBlock in
            Log("Received promoted product callback", module: .mainRepository)
            if callback() {
                guard let self else { return }
                Log("Handling promoted product callback", module: .mainRepository)
                startPurchaseBlock { self.handlePurchaseBlock(transaction: $0, info: $1, error: $2, cancelled: $3) }
            } else {
                Log("Deferring promoted product callback", module: .mainRepository)
                self?._startPurchaseBlock = startPurchaseBlock
            }
        }
    }
    
    func paymentUpdatePaymentStatus(subscriptionName: String) {
        Log("Updating payment status", module: .mainRepository)
        Purchases.shared.getCustomerInfo { [weak self] (customerInfo, error) in
            if let entitlement = customerInfo?.entitlements[subscriptionName], entitlement.isActive == true {
                Log("Premium user", module: .mainRepository)
                self?.updatePaymentStatus(entitlement: entitlement)
            } else {
                Log("Non - premium user", module: .mainRepository)
                self?.updatePaymentStatus(entitlement: nil)
            }
        }
    }
    
    func paymentSubscriptionPrice(subscriptionName: String) async -> String? {
        await withCheckedContinuation { continuation in
            Purchases.shared.getCustomerInfo { customerInfo, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }
                
                if let entitlement = customerInfo?.entitlements[subscriptionName], entitlement.isActive == true {
                    Purchases.shared.getOfferings { offerings, error in
                        guard let offering = offerings?.current else {
                            continuation.resume(returning: nil)
                            return
                        }
                        
                        if let matchingProduct = offering.availablePackages.first(where: { $0.storeProduct.productIdentifier == entitlement.productIdentifier }) {
                            let price = matchingProduct.storeProduct.localizedPriceString
                            continuation.resume(returning: price)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func paymentRunCachedPromotedPurchase() {
        Log("Handling deferred promoted product callback", module: .mainRepository)
        _startPurchaseBlock? { self.handlePurchaseBlock(transaction: $0, info: $1, error: $2, cancelled: $3) }
        _startPurchaseBlock = nil
    }
}

extension MainRepositoryImpl {
    
    var isOverridedSubscriptionPlan: Bool {
        userDefaultsDataSource.debugSubscriptionPlan != nil
    }
    
    func overrideSubscriptionPlan(_ plan: SubscriptionPlan) {
        userDefaultsDataSource.setDebugSubscriptionPlan(plan)
        notificationCenter.post(name: .paymentStatusChanged, object: nil)
    }
    
    func clearOverrideSubscriptionPlan() {
        userDefaultsDataSource.clearDebugSubscriptionPlan()
        notificationCenter.post(name: .paymentStatusChanged, object: nil)
    }
}

private extension MainRepositoryImpl {
    func updatePaymentStatus(entitlement: EntitlementInfo?) {
        let currentIsPremium = _subscriptionPlan.planType == .premium
        
        guard currentIsPremium != (entitlement != nil) else { return }
        
        if let entitlement {
            _subscriptionPlan = SubscriptionPlan(
                planType: .premium,
                paymentInfo: .init(
                    expirationDate: entitlement.expirationDate,
                    willRenew: entitlement.willRenew
                )
            )
        } else {
            _subscriptionPlan = .free
        }
        
        notificationCenter.post(name: .paymentStatusChanged, object: nil)
    }
    
    func handlePurchaseBlock(transaction: StoreTransaction?, info: CustomerInfo?, error: PublicError?, cancelled: Bool) {
        if let info = info, error == nil, !cancelled {
            revenueCatDelegate.receivedUpdate?(info)
        }
    }
}

private extension LogLevel {
    var severity: LogSeverity {
        switch self {
        case .verbose, .debug: .trace
        case .info: .info
        case .warn: .warning
        case .error: .error
        }
    }
}
