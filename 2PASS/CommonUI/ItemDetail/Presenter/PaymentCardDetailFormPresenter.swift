// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

@Observable
final class PaymentCardDetailFormPresenter: ItemDetailFormPresenter {

    private(set) var paymentCardItem: PaymentCardItemData

    var cardHolder: String? {
        paymentCardItem.content.cardHolder
    }

    var notes: String? {
        paymentCardItem.content.notes
    }

    var cardNumberMask: String? {
        paymentCardItem.content.cardNumberMask
    }

    var paymentCardIssuer: String? {
        paymentCardItem.content.cardIssuer
    }

    var paymentCardIcon: IconContent {
        if let icon = paymentCardItem.issuerIcon {
            return .icon(icon)
        }
        return .contentType(.paymentCard)
    }

    var cardNumber: String?
    var expirationDate: String?
    var securityCode: String?

    init(item: PaymentCardItemData, configuration: ItemDetailFormConfiguration) {
        self.paymentCardItem = item
        super.init(item: item, configuration: configuration)
        refreshValues()
    }

    func reload() {
        guard let newPaymentCard = interactor.fetchItem(for: paymentCardItem.id)?.asPaymentCard else {
            return
        }
        self.paymentCardItem = newPaymentCard
        refreshValues()
    }

    func onSelectCardNumber() {
        guard let decrypted = decryptCardNumber() else { return }

        if autoFillEnvironment?.isTextToInsert == true {
            flowController.autoFillTextToInsert(decrypted)
        } else {
            cardNumber = PaymentCardNumberFormatStyle().format(decrypted)
        }
    }

    func onSelectSecurityCode() {
        guard let decrypted = decryptSecurityCode() else { return }

        if autoFillEnvironment?.isTextToInsert == true {
            flowController.autoFillTextToInsert(decrypted)
        } else {
            securityCode = decrypted
        }
    }

    func onCopyCardHolder() {
        if let cardHolder {
            interactor.copy(cardHolder)
            toastPresenter.presentCopied()
        }
    }

    func onCopyCardNumber() {
        if let decrypted = decryptCardNumber() {
            interactor.copy(decrypted)
            toastPresenter.presentPaymentCardNumberCopied()
        }
    }

    func onCopyExpirationDate() {
        if let expirationDate {
            interactor.copy(expirationDate)
            toastPresenter.presentCopied()
        }
    }

    func onCopySecurityCode() {
        if let decrypted = decryptSecurityCode() {
            interactor.copy(decrypted)
            toastPresenter.presentPaymentCardSecurityCodeCopied()
        }
    }

    private func refreshValues() {
        if let mask = cardNumberMask {
            cardNumber = PaymentCardNumberMaskFormatStyle().format(mask)
        } else {
            cardNumber = nil
        }

        if let encrypted = paymentCardItem.content.expirationDate {
            expirationDate = interactor.decryptSecureField(encrypted, protectionLevel: paymentCardItem.protectionLevel)
        } else {
            expirationDate = nil
        }

        if paymentCardItem.content.securityCode != nil {
            securityCode = "•••"
        } else {
            securityCode = nil
        }
    }

    private func decryptCardNumber() -> String? {
        guard let encrypted = paymentCardItem.content.cardNumber else { return nil }
        return interactor.decryptSecureField(encrypted, protectionLevel: paymentCardItem.protectionLevel)
    }

    private func decryptSecurityCode() -> String? {
        guard let encrypted = paymentCardItem.content.securityCode else { return nil }
        return interactor.decryptSecureField(encrypted, protectionLevel: paymentCardItem.protectionLevel)
    }
}
