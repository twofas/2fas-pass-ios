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
                let mask = decryptedCardNumber == nil ? initialPaymentCardItem?.content.cardNumberMask : interactor.paymentCardNumberMask(from: decryptedCardNumber)
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
            decryptedSecurityCode ?? (initialPaymentCardItem?.content.securityCode != nil ? String(repeating: "•", count: maxSecurityCodeLength) : "")
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
        
    private(set) var isSecurityCodeInvalid: Bool = false
    private(set) var isCardNumberInvalid: Bool = false
    private(set) var isExpirationDateInvalid: Bool = false

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
        let isExpirationDateValid = validateExpirationDate(expirationDate)
        let isSecurityCodeValid = validateSecurityCode(decryptedSecurityCode)
        let isCardNumberValid = validateCardNumber(decryptedCardNumber)
        return isCardNumberValid && isSecurityCodeValid && isExpirationDateValid
    }
    
    var decryptedSecurityCode: String? {
        didSet {
            if isSecurityCodeLiveValidation {
                updateSecurityCodeValidity()
            }
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

    init(
        interactor: ItemEditorModuleInteracting,
        flowController: ItemEditorFlowControlling,
        initialData: PaymentCardItemData? = nil,
        changeRequest: PaymentCardDataChangeRequest? = nil
    ) {
        if let initialData {
            let decryptedExpirationDate = initialData.content.expirationDate.flatMap {
                interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
            }.map { $0.formatted(.expirationDate) } ?? ""
            let changeRequestExpirationDate = changeRequest?.expirationDate.map { $0.formatted(.expirationDate) }

            self.cardHolder = changeRequest?.cardHolder ?? initialData.content.cardHolder ?? ""
            self.expirationDate = changeRequestExpirationDate ?? decryptedExpirationDate
            self.notes = changeRequest?.notes ?? initialData.content.notes ?? ""

            self.initialCardIssuer = initialData.content.cardIssuer.flatMap { PaymentCardIssuer(rawValue: $0) }
            self.initialExpirationDate = decryptedExpirationDate

            if let cardNumberFromRequest = changeRequest?.cardNumber {
                self.decryptedCardNumber = cardNumberFromRequest
                self.isCardNumberRevealed = true
                self.initialCardNumber = initialData.content.cardNumber.flatMap {
                    interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
                }
            } else {
                self.isCardNumberRevealed = initialData.content.cardNumber == nil
            }

            if let securityCodeFromRequest = changeRequest?.securityCode {
                self.decryptedSecurityCode = securityCodeFromRequest
                self.initialSecurityCode = initialData.content.securityCode.flatMap {
                    interactor.decryptSecureField($0, protectionLevel: initialData.protectionLevel)
                }
            }
        } else {
            self.cardHolder = changeRequest?.cardHolder ?? ""
            self.decryptedCardNumber = changeRequest?.cardNumber ?? ""
            self.expirationDate = changeRequest?.expirationDate.map { $0.formatted(.expirationDate) } ?? ""
            self.decryptedSecurityCode = changeRequest?.securityCode ?? ""
            self.notes = changeRequest?.notes ?? ""
            
            self.initialCardIssuer = nil
            self.initialExpirationDate = nil
        }

        super.init(interactor: interactor, flowController: flowController, initialData: initialData, changeRequest: changeRequest)
        
        updatePaymentCardNumberValidity()
        updateExpirationDateValidity()
        updateSecurityCodeValidity()
    }
    
    func onExpirationDateFocusChange(isFocused: Bool) {
        isExpirationDateLiveValidation = isFocused ? expirationDate.isEmpty == false : true
        updateExpirationDateValidity()
    }

    func onExpirationDateChange() {
        if isExpirationDateLiveValidation {
            isExpirationDateInvalid = !expirationDate.isEmpty && !validateExpirationDate(expirationDate)
        }
    }

    func onSecurityCodeFocusChange(isFocused: Bool) {
        if isFocused {
            decryptSecurityCodeIfNeeded()
        }
        
        isSecurityCodeLiveValidation = isFocused ? decryptedSecurityCode?.isEmpty == false : true
        updateSecurityCodeValidity()
    }

    func onCardNumberFocusChange(isFocused: Bool) {
        isCardNumberRevealed = isFocused
        isCardNumberLiveValidation = isFocused ? decryptedCardNumber?.isEmpty == false : true
        updatePaymentCardNumberValidity()
    }

    func onCardNumberChange() {
        if isCardNumberLiveValidation {
            updatePaymentCardNumberValidity()
        }
    }

    func onSave() -> SaveItemResult {
        decryptCardNumberIfNeeded()
        decryptSecurityCodeIfNeeded()
        
        return interactor.savePaymentCard(
            name: name,
            cardHolder: cardHolder.nonBlankTrimmedOrNil,
            cardNumber: decryptedCardNumber.nilIfEmpty,
            expirationDate: normalizedExpirationDate(expirationDate).nonBlankTrimmedOrNil,
            securityCode: decryptedSecurityCode.nilIfEmpty,
            notes: notes.nonBlankTrimmedOrNil,
            protectionLevel: protectionLevel,
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }
    
    private func updateSecurityCodeValidity() {
        isSecurityCodeInvalid = validateSecurityCode(decryptedSecurityCode) == false
    }
    
    private func updatePaymentCardNumberValidity() {
        isCardNumberInvalid = validateCardNumber(decryptedCardNumber) == false
    }
    
    private func updateExpirationDateValidity() {
        isExpirationDateInvalid = validateExpirationDate(expirationDate) == false
    }
    
    private func validateCardNumber(_ value: String?) -> Bool {
        guard let value else {
            return true
        }
        return value.isEmpty || interactor.validatePaymentCardCardNumber(value, for: paymentCardIssuer)
    }
    
    private func validateExpirationDate(_ value: String) -> Bool {
        let expirationDate = normalizedExpirationDate(value)
        return expirationDate.isEmpty || interactor.validatePaymentCardExpirationDate(expirationDate)
    }
    
    private func validateSecurityCode(_ value: String?) -> Bool {
        guard let value else {
            return true
        }
        return value.isEmpty || interactor.validatePaymentCardSecurityCode(value, for: paymentCardIssuer)
    }
    
    private func normalizedExpirationDate(_ expirationDate: String) -> String {
        expirationDate.filter { $0.isNumber || $0 == "/" }
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
        guard let item = initialPaymentCardItem, let encrypted = item.content.securityCode else {
            decryptedSecurityCode = ""
            initialSecurityCode = initialSecurityCode ?? ""
            return
        }

        let decrypted = interactor.decryptSecureField(encrypted, protectionLevel: item.protectionLevel)
        decryptedSecurityCode = decrypted
        initialSecurityCode = decrypted
    }
}
