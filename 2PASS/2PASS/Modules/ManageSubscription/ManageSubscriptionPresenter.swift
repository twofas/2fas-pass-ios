// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

@Observable
final class ManageSubscriptionPresenter {
    
    let itemsCount: Int
    let webBrowsersCount: Int
    let renewDate: String?
    let willRenew: Bool
    let userIdentifier: String?
    private(set) var renewPrice: String?
    
    private let interactor: ManageSubscriptionModuleInteracting
    
    init(interactor: ManageSubscriptionModuleInteracting) {
        self.interactor = interactor
        
        self.itemsCount = interactor.itemsCount
        self.webBrowsersCount = interactor.connectedWebBrowsersCount
        self.renewDate = {
            if let renewDate = interactor.subscriptionPlan.paymentInfo?.expirationDate {
                return Date.FormatStyle(date: .numeric).format(renewDate)
            } else {
                return nil
            }
        }()
        self.willRenew = interactor.subscriptionPlan.paymentInfo?.willRenew ?? false
        self.userIdentifier = interactor.userId
    }
    
    func onAppear() async {
        renewPrice = await interactor.fetchRenewPrice()
    }
    
    func onUserIdentifierCopy() {
        guard let userIdentifier else { return }
        interactor.copy(userIdentifier)
        ToastPresenter.shared.presentCopied()
    }
}
