// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

@Observable
final class CardDetailFormPresenter: ItemDetailFormPresenter {

    private(set) var cardItem: CardItemData

    var cardHolder: String? {
        cardItem.content.cardHolder
    }

    var notes: String? {
        cardItem.content.notes
    }

    var cardNumberMask: String? {
        cardItem.content.cardNumberMask
    }

    var cardIssuer: String? {
        cardItem.content.cardIssuer
    }

    var cardIcon: IconContent {
        if let icon = cardItem.issuerIcon {
            return .icon(icon)
        }
        return .contentType(.card)
    }

    var cardNumber: String?
    var expirationDate: String?
    var securityCode: String?

    init(item: CardItemData, configuration: ItemDetailFormConfiguration) {
        self.cardItem = item
        super.init(item: item, configuration: configuration)
        refreshValues()
    }

    func reload() {
        guard let newCard = interactor.fetchItem(for: cardItem.id)?.asCard else {
            return
        }
        self.cardItem = newCard
        refreshValues()
    }

    func onSelectCardNumber() {
        guard let decrypted = decryptCardNumber() else { return }

        if autoFillEnvironment?.isTextToInsert == true {
            flowController.autoFillTextToInsert(decrypted)
        } else {
            cardNumber = CardNumberFormatStyle().format(decrypted)
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
            toastPresenter.presentCardNumberCopied()
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
            toastPresenter.presentCardSecurityCodeCopied()
        }
    }

    private func refreshValues() {
        if let mask = cardNumberMask {
            cardNumber = CardNumberMaskFormatStyle().format(mask)
        } else {
            cardNumber = nil
        }

        if let encrypted = cardItem.content.expirationDate {
            expirationDate = interactor.decryptSecureField(encrypted, protectionLevel: cardItem.protectionLevel)
        } else {
            expirationDate = nil
        }

        if cardItem.content.securityCode != nil {
            securityCode = "•••"
        } else {
            securityCode = nil
        }
    }

    private func decryptCardNumber() -> String? {
        guard let encrypted = cardItem.content.cardNumber else { return nil }
        return interactor.decryptSecureField(encrypted, protectionLevel: cardItem.protectionLevel)
    }

    private func decryptSecurityCode() -> String? {
        guard let encrypted = cardItem.content.securityCode else { return nil }
        return interactor.decryptSecureField(encrypted, protectionLevel: cardItem.protectionLevel)
    }
}
