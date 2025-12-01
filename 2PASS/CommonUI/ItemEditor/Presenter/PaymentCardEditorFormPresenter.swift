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
    var cardNumber: String?
    var expirationDate: String = ""
    var securityCode: String?
    var notes: String = ""
    
    var isSecurityCodeInvalid: Bool = false
    var isCardNumberInvalid: Bool = false
    var isExpirationDateInvalid: Bool = false

    private var isSecurityCodeLiveValidation: Bool = false
    private var isCardNumberLiveValidation: Bool = false
    private var isExpirationDateLiveValidation: Bool = false

    var isCardNumberRevealed: Bool = true {
        didSet {
            if isCardNumberRevealed && !oldValue {
                decryptCardNumberIfNeeded()
            }
        }
    }
    var isSecurityCodeRevealed: Bool = true

    var displayedCardNumber: String {
        get {
            if isCardNumberRevealed {
                return cardNumber ?? ""
            } else {
                let mask = cardNumberMask ?? initialCardNumberMask
                return mask?.formatted(.paymentCardNumberMask) ?? ""
            }
        }
        set {
            if isCardNumberRevealed {
                cardNumber = newValue
            }
        }
    }

    private var cardNumberMask: String? {
        interactor.paymentCardNumberMask(from: cardNumber)
    }

    var displayedSecurityCode: String {
        get {
            if isSecurityCodeRevealed {
                return securityCode ?? ""
            } else {
                return String(repeating: "•", count: maxSecurityCodeLength)
            }
        }
        set {
            if isSecurityCodeRevealed {
                securityCode = newValue
            }
        }
    }

    var paymentCardIssuer: PaymentCardIssuer? {
        let cardIssuer = interactor.detectPaymentCardIssuer(from: cardNumber)
        
        if isCardNumberRevealed {
            return cardIssuer
        } else {
            return cardIssuer ?? initialCardIssuer
        }
    }

    var paymentCardIssuerIcon: UIImage? {
        paymentCardIssuer?.icon
    }

    var maxCardNumberLength: Int {
        interactor.maxPaymentCardNumberLength(for: paymentCardIssuer)
    }

    var maxSecurityCodeLength: Int {
        interactor.maxPaymentCardSecurityCodeLength(for: paymentCardIssuer)
    }

    var cardNumberFormatStyle: PaymentCardNumberFormatStyle {
        PaymentCardNumberFormatStyle(issuer: paymentCardIssuer)
    }

    override var canSave: Bool {
        guard super.canSave else { return false }
        let isExpirationDateValid = expirationDate.isEmpty || validateExpirationDate(expirationDate)
        let isSecurityCodeValid = securityCode?.isEmpty != false || securityCode.map { validateSecurityCode($0) } == true
        let isCardNumberValid = cardNumber?.isEmpty == true || cardNumber.map { validateCardNumber($0) } == true
        return isExpirationDateValid && isSecurityCodeValid && isCardNumberValid
    }

    private var initialCardHolder: String?
    private var initialCardNumber: String?
    private var initialCardNumberMask: String?
    private var initialCardIssuer: PaymentCardIssuer?
    private var initialExpirationDate: String?
    private var initialSecurityCode: String?
    private var initialNotes: String?

    private var encryptedCardNumber: Data?
    private var encryptedSecurityCode: Data?

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

    func validateExpirationDate(_ value: String) -> Bool {
        interactor.validatePaymentCardExpirationDate(value)
    }

    func onExpirationDateFocusChange(isFocused: Bool) {
        if isFocused {
            isExpirationDateLiveValidation = !expirationDate.isEmpty
        } else {
            isExpirationDateInvalid = !expirationDate.isEmpty && !validateExpirationDate(expirationDate)
        }
    }

    func onExpirationDateChange() {
        if isExpirationDateLiveValidation {
            isExpirationDateInvalid = !expirationDate.isEmpty && !validateExpirationDate(expirationDate)
        }
    }

    func validateSecurityCode(_ value: String) -> Bool {
        interactor.validatePaymentCardSecurityCode(value, for: paymentCardIssuer)
    }

    func onSecurityCodeFocusChange(isFocused: Bool) {
        if isFocused {
            isSecurityCodeLiveValidation = securityCode?.isEmpty == false
        } else {
            isSecurityCodeInvalid = securityCode?.isEmpty == false && securityCode.map { validateSecurityCode($0) } == false
        }
    }

    func onSecurityCodeChange() {
        if isSecurityCodeLiveValidation {
            isSecurityCodeInvalid = securityCode?.isEmpty == false && securityCode.map { validateSecurityCode($0) } == false
        }
    }

    func validateCardNumber(_ value: String) -> Bool {
        interactor.validatePaymentCardCardNumber(value, for: paymentCardIssuer)
    }

    func onCardNumberFocusChange(isFocused: Bool) {
        if isFocused {
            isCardNumberLiveValidation = cardNumber?.isEmpty == false
        } else {
            isCardNumberInvalid = cardNumber?.isEmpty == false && cardNumber.map { validateCardNumber($0) } == false
        }
    }

    func onCardNumberChange() {
        if isCardNumberLiveValidation {
            isCardNumberInvalid = cardNumber?.isEmpty == false && cardNumber.map { validateCardNumber($0) } == false
        }
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
            let decryptedExpirationDate = initialData.content.expirationDate.flatMap {
                interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
            } ?? ""

            self.cardHolder = changeRequest?.cardHolder ?? initialData.content.cardHolder ?? ""
            self.expirationDate = changeRequest?.expirationDate ?? decryptedExpirationDate
            self.notes = changeRequest?.notes ?? initialData.content.notes ?? ""

            self.initialCardHolder = initialData.content.cardHolder ?? ""
            self.initialCardNumberMask = initialData.content.cardNumberMask
            self.initialCardIssuer = initialData.content.cardIssuer.flatMap { PaymentCardIssuer(rawValue: $0) }
            self.initialExpirationDate = decryptedExpirationDate
            self.initialNotes = initialData.content.notes ?? ""

            // Store encrypted data for on-demand decryption
            self.encryptedCardNumber = initialData.content.cardNumber
            self.encryptedSecurityCode = initialData.content.securityCode

            // Handle change request - decrypt if needed
            if let cardNumberFromRequest = changeRequest?.cardNumber {
                self.cardNumber = cardNumberFromRequest
                self.isCardNumberRevealed = true
            } else {
                self.isCardNumberRevealed = initialData.content.cardNumber == nil
            }

            if let securityCodeFromRequest = changeRequest?.securityCode {
                self.securityCode = securityCodeFromRequest
                self.isSecurityCodeRevealed = true
            } else {
                self.isSecurityCodeRevealed = initialData.content.securityCode == nil
            }
        } else {
            self.cardHolder = changeRequest?.cardHolder ?? ""
            self.cardNumber = changeRequest?.cardNumber ?? ""
            self.expirationDate = changeRequest?.expirationDate ?? ""
            self.securityCode = changeRequest?.securityCode ?? ""
            self.notes = changeRequest?.notes ?? ""
        }

        super.init(interactor: interactor, flowController: flowController, initialData: initialData, changeRequest: changeRequest)
    }

    func revealCardNumber() {
        guard !isCardNumberRevealed else { return }
        isCardNumberRevealed = true
    }

    private func decryptCardNumberIfNeeded() {
        guard cardNumber == nil else { return }
        if let encrypted = encryptedCardNumber,
           let item = initialPaymentCardItem {
            let decrypted = interactor.decryptSecureField(encrypted, protectionLevel: item.protectionLevel) ?? ""
            cardNumber = decrypted
            initialCardNumber = decrypted
        }
    }

    func revealSecurityCode() {
        guard !isSecurityCodeRevealed else { return }
        decryptSecurityCodeIfNeeded()
        isSecurityCodeRevealed = true
    }

    private func decryptSecurityCodeIfNeeded() {
        guard securityCode == nil else { return }
        if let encrypted = encryptedSecurityCode,
           let item = initialPaymentCardItem {
            let decrypted = interactor.decryptSecureField(encrypted, protectionLevel: item.protectionLevel)
            securityCode = decrypted
            initialSecurityCode = decrypted
        }
    }

    func onSave() -> SaveItemResult {
        decryptCardNumberIfNeeded()
        decryptSecurityCodeIfNeeded()

        return interactor.savePaymentCard(
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
