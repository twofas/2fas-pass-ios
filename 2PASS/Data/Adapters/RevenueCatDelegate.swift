// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import RevenueCat

final class RevenueCatDelegate: NSObject, PurchasesDelegate {
    var receivedUpdate: ((CustomerInfo) -> Void)?
    var readyForPromotedProduct: ((@escaping StartPurchaseBlock) -> Void)?
    
    var shouldShowPriceConsent: Bool { true }
    
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        self.receivedUpdate?(customerInfo)
    }
    
    func purchases(
        _ purchases: Purchases,
        readyForPromotedProduct product: StoreProduct,
        purchase startPurchase: @escaping StartPurchaseBlock
    ) {
        self.readyForPromotedProduct?(startPurchase)
    }
}
