// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common

protocol ManageSubscriptionModuleInteracting {
    var userId: String? { get }
    var itemsCount: Int { get }
    var connectedWebBrowsersCount: Int { get }
    var subscriptionPlan: SubscriptionPlan { get }
    
    func copy(_ str: String)
    func fetchRenewPrice() async -> String?
}

final class ManageSubscriptionModuleInteractor: ManageSubscriptionModuleInteracting {
    
    private let passwordInteractor: PasswordInteracting
    private let webBrowsersInteractor: WebBrowsersInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    private let systemInteractor: SystemInteracting
    
    init(passwordInteractor: PasswordInteracting,
         webBrowsersInteractor: WebBrowsersInteracting,
         paymentStatusInteractor: PaymentStatusInteracting,
         systemInteractor: SystemInteracting
    ) {
        self.passwordInteractor = passwordInteractor
        self.webBrowsersInteractor = webBrowsersInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
        self.systemInteractor = systemInteractor
    }
    
    var userId: String? {
        paymentStatusInteractor.userId
    }
    
    var itemsCount: Int {
        passwordInteractor.itemsCount
    }
    
    @MainActor
    var connectedWebBrowsersCount: Int {
        webBrowsersInteractor.list().count
    }
    
    var subscriptionPlan: SubscriptionPlan {
        paymentStatusInteractor.plan
    }
    
    func fetchRenewPrice() async -> String? {
        await paymentStatusInteractor.fetchRenewPrice()
    }
    
    func copy(_ str: String) {
        systemInteractor.copyToClipboard(str)
    }
}
