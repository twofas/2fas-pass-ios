// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import UIKit

@Observable
final class PaymentCardEditorFormPresenter: ItemEditorFormPresenter {

    var cardHolder: String = ""
    var cardNumber: String = ""
    var expirationDate: String = ""
    var securityCode: String = ""
    var notes: String = ""

    var paymentCardIssuerIcon: UIImage? {
        interactor.detectPaymentCardIssuer(from: cardNumber)?.icon
    }

    private var initialCardHolder: String?
    private var initialCardNumber: String?
    private var initialExpirationDate: String?
    private var initialSecurityCode: String?
    private var initialNotes: String?

    private var initialPaymentCardItem: PaymentCardItemData? {
        initialData as? PaymentCardItemData
    }
    
    var cardHolderChanged: Bool {
        guard let initialCardHolder else { return false }
        return cardHolder != initialCardHolder
    }

    var cardNumberChanged: Bool {
        guard let initialCardNumber else { return false }
        return cardNumber != initialCardNumber
    }

    var expirationDateChanged: Bool {
        guard let initialExpirationDate else { return false }
        return expirationDate != initialExpirationDate
    }

    var securityCodeChanged: Bool {
        guard let initialSecurityCode else { return false }
        return securityCode != initialSecurityCode
    }

    var notesChanged: Bool {
        guard let initialNotes else { return false }
        return notes != initialNotes
    }

    init(
        interactor: ItemEditorModuleInteracting,
        flowController: ItemEditorFlowControlling,
        initialData: PaymentCardItemData? = nil,
        changeRequest: PaymentCardDataChangeRequest? = nil
    ) {
        if let initialData {
            let decryptedCardNumber = initialData.content.cardNumber.flatMap {
                interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
            } ?? ""
            let decryptedExpirationDate = initialData.content.expirationDate.flatMap {
                interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
            } ?? ""
            let decryptedSecurityCode = initialData.content.securityCode.flatMap {
                interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
            } ?? ""

            self.cardHolder = changeRequest?.cardHolder ?? initialData.content.cardHolder ?? ""
            self.cardNumber = changeRequest?.cardNumber ?? decryptedCardNumber
            self.expirationDate = changeRequest?.expirationDate ?? decryptedExpirationDate
            self.securityCode = changeRequest?.securityCode ?? decryptedSecurityCode
            self.notes = changeRequest?.notes ?? initialData.content.notes ?? ""

            self.initialCardHolder = initialData.content.cardHolder ?? ""
            self.initialCardNumber = decryptedCardNumber
            self.initialExpirationDate = decryptedExpirationDate
            self.initialSecurityCode = decryptedSecurityCode
            self.initialNotes = initialData.content.notes ?? ""
        } else {
            self.cardHolder = changeRequest?.cardHolder ?? ""
            self.cardNumber = changeRequest?.cardNumber ?? ""
            self.expirationDate = changeRequest?.expirationDate ?? ""
            self.securityCode = changeRequest?.securityCode ?? ""
            self.notes = changeRequest?.notes ?? ""
        }

        super.init(interactor: interactor, flowController: flowController, initialData: initialData, changeRequest: changeRequest)
    }

    func onSave() -> SaveItemResult {
        interactor.savePaymentCard(
            name: name,
            cardHolder: cardHolder.nilIfEmpty,
            cardNumber: cardNumber.nilIfEmpty,
            expirationDate: expirationDate.nilIfEmpty,
            securityCode: securityCode.nilIfEmpty,
            notes: notes.nilIfEmpty,
            protectionLevel: protectionLevel,
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }
}
