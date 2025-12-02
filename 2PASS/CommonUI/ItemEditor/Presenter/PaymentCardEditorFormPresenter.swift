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
    var expirationDate: String = ""
    var notes: String = ""

    var cardNumber: String {
        get {
            if isCardNumberRevealed {
                return decryptedCardNumber ?? ""
            } else {
                let mask = interactor.paymentCardNumberMask(from: decryptedCardNumber) ?? initialPaymentCardItem?.content.cardNumberMask
                return mask?.formatted(.paymentCardNumberMask) ?? ""
            }
        }
        set {
            if isCardNumberRevealed {
                decryptedCardNumber = newValue
            }
        }
    }
    
    var securityCode: String {
        get {
            decryptedSecurityCode ?? String(repeating: "•", count: maxSecurityCodeLength)
        }
        set {
            if decryptedSecurityCode != nil {
                decryptedSecurityCode = newValue
            }
        }
    }
    
    var securityCodeRevealed = false {
        didSet {
            if securityCodeRevealed {
                decryptSecurityCodeIfNeeded()
            }
        }
    }
        
    var isSecurityCodeInvalid: Bool = false
    var isCardNumberInvalid: Bool = false
    var isExpirationDateInvalid: Bool = false

    private var isSecurityCodeLiveValidation: Bool = true
    private var isCardNumberLiveValidation: Bool = false
    private var isExpirationDateLiveValidation: Bool = false

    var isCardNumberRevealed: Bool = true {
        didSet {
            if isCardNumberRevealed && !oldValue {
                decryptCardNumberIfNeeded()
            }
        }
    }

    var paymentCardIssuer: PaymentCardIssuer? {
        let cardIssuer = interactor.detectPaymentCardIssuer(from: decryptedCardNumber)
        
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
        let isSecurityCodeValid = decryptedSecurityCode?.isEmpty != false || decryptedSecurityCode.map { validateSecurityCode($0) } == true
        let isCardNumberValid = decryptedCardNumber == nil || decryptedCardNumber?.isEmpty == true || decryptedCardNumber.map { validateCardNumber($0) } == true
        return isCardNumberValid && isSecurityCodeValid && isExpirationDateValid
    }
    
    var decryptedSecurityCode: String? {
        didSet {
            updateSecurityCodeValidity()
        }
    }
    var decryptedCardNumber: String? {
        didSet {
            updateSecurityCodeValidity()
        }
    }

    private let initialCardIssuer: PaymentCardIssuer?
    private let initialExpirationDate: String?
    private var initialCardNumber: String?
    private var initialSecurityCode: String?

    private var initialPaymentCardItem: PaymentCardItemData? {
        initialData as? PaymentCardItemData
    }

    var cardHolderChanged: Bool {
        guard let initialPaymentCardItem else { return false }
        return cardHolder != initialPaymentCardItem.content.cardHolder ?? ""
    }

    var cardNumberChanged: Bool {
        guard let initialCardNumber else { return false }
        return decryptedCardNumber != initialCardNumber
    }

    var expirationDateChanged: Bool {
        guard let initialExpirationDate else { return false }
        return expirationDate != initialExpirationDate
    }
    
    var securityCodeChanged: Bool {
        guard let initialSecurityCode else { return false }
        return decryptedSecurityCode != initialSecurityCode
    }

    var notesChanged: Bool {
        guard let initialPaymentCardItem else { return false }
        return notes != initialPaymentCardItem.content.notes ?? ""
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

    func onSecurityCodeFocusChange(isFocused: Bool) {
        if isFocused {
            decryptSecurityCodeIfNeeded()
            isSecurityCodeLiveValidation = decryptedSecurityCode?.isEmpty == false
        } else {
            isSecurityCodeInvalid = validateSecurityCode(decryptedSecurityCode) == false
            isSecurityCodeLiveValidation = true
        }
    }

    func validateCardNumber(_ value: String) -> Bool {
        interactor.validatePaymentCardCardNumber(value, for: paymentCardIssuer)
    }

    func onCardNumberFocusChange(isFocused: Bool) {
        if isFocused {
            isCardNumberLiveValidation = decryptedCardNumber?.isEmpty == false
        } else {
            isCardNumberInvalid = decryptedCardNumber?.isEmpty == false && decryptedCardNumber.map { validateCardNumber($0) } == false
        }
    }

    func onCardNumberChange() {
        if isCardNumberLiveValidation {
            isCardNumberInvalid = decryptedCardNumber?.isEmpty == false && decryptedCardNumber.map { validateCardNumber($0) } == false
        }
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

            self.initialCardIssuer = initialData.content.cardIssuer.flatMap { PaymentCardIssuer(rawValue: $0) }
            self.initialExpirationDate = decryptedExpirationDate

            // Handle change request - decrypt if needed
            if let cardNumberFromRequest = changeRequest?.cardNumber {
                self.decryptedCardNumber = cardNumberFromRequest
                self.isCardNumberRevealed = true
            } else {
                self.isCardNumberRevealed = initialData.content.cardNumber == nil
            }

            if let securityCodeFromRequest = changeRequest?.securityCode {
                self.decryptedSecurityCode = securityCodeFromRequest
                self.initialSecurityCode = securityCodeFromRequest
            } else {
                self.decryptedSecurityCode = initialData.content.securityCode == nil ? "" : nil
                self.initialSecurityCode = initialData.content.securityCode == nil ? "" : nil
            }
        } else {
            self.cardHolder = changeRequest?.cardHolder ?? ""
            self.decryptedCardNumber = changeRequest?.cardNumber ?? ""
            self.expirationDate = changeRequest?.expirationDate ?? ""
            self.decryptedSecurityCode = changeRequest?.securityCode ?? ""
            self.notes = changeRequest?.notes ?? ""
            
            self.initialCardIssuer = nil
            self.initialExpirationDate = nil
        }

        super.init(interactor: interactor, flowController: flowController, initialData: initialData, changeRequest: changeRequest)
    }

    func revealCardNumber() {
        guard !isCardNumberRevealed else { return }
        isCardNumberRevealed = true
    }

    func onSave() -> SaveItemResult {
        decryptCardNumberIfNeeded()
        decryptSecurityCodeIfNeeded()

        return interactor.savePaymentCard(
            name: name,
            cardHolder: cardHolder.nilIfEmpty,
            cardNumber: decryptedCardNumber.nilIfEmpty,
            expirationDate: expirationDate.nilIfEmpty,
            securityCode: decryptedSecurityCode.nilIfEmpty,
            notes: notes.nilIfEmpty,
            protectionLevel: protectionLevel,
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }
    
    private func updateSecurityCodeValidity() {
        if isSecurityCodeLiveValidation {
            isSecurityCodeInvalid = validateSecurityCode(decryptedSecurityCode) == false
        }
    }
    
    private func validateSecurityCode(_ value: String?) -> Bool {
        guard let value else {
            return false
        }
        return value.isEmpty || interactor.validatePaymentCardSecurityCode(value, for: paymentCardIssuer)
    }
    
    private func decryptCardNumberIfNeeded() {
        guard decryptedCardNumber == nil else { return }
        guard let item = initialPaymentCardItem, let encrypted = item.content.cardNumber else { return }

        let decrypted = interactor.decryptSecureField(encrypted, protectionLevel: item.protectionLevel) ?? ""
        decryptedCardNumber = decrypted
        initialCardNumber = decrypted
    }
    
    private func decryptSecurityCodeIfNeeded() {
        guard decryptedSecurityCode == nil else { return }
        guard let item = initialPaymentCardItem, let encrypted = item.content.securityCode else { return }
        
        let decrypted = interactor.decryptSecureField(encrypted, protectionLevel: item.protectionLevel)
        decryptedSecurityCode = decrypted
        initialSecurityCode = decrypted
    }
}
