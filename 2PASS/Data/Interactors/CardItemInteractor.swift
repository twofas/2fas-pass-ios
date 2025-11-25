// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol CardItemInteracting: AnyObject {
    func createCard(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError)

    func updateCard(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError)

    func detectCardIssuer(from cardNumber: String?) -> CardIssuer?
    func makeCardNumberMask(from cardNumber: String?) -> String?
}

final class CardItemInteractor {
    private let itemsInteractor: ItemsInteracting
    private let mainRepository: MainRepository

    init(itemsInteractor: ItemsInteracting, mainRepository: MainRepository) {
        self.itemsInteractor = itemsInteractor
        self.mainRepository = mainRepository
    }
}

extension CardItemInteractor: CardItemInteracting {

    func createCard(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let cardItem = try makeCard(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            cardHolder: cardHolder,
            cardNumber: cardNumber,
            expirationDate: expirationDate,
            securityCode: securityCode,
            notes: notes
        )
        try itemsInteractor.createItem(.card(cardItem))
    }

    func updateCard(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let cardItem = try makeCard(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            cardHolder: cardHolder,
            cardNumber: cardNumber,
            expirationDate: expirationDate,
            securityCode: securityCode,
            notes: notes
        )
        try itemsInteractor.updateItem(.card(cardItem))
    }

    func detectCardIssuer(from cardNumber: String?) -> CardIssuer? {
        guard let cardNumber = cardNumber?.trim(), !cardNumber.isEmpty else {
            return nil
        }
        let digitsOnly = cardNumber.filter { $0.isNumber }
        guard digitsOnly.count >= 4 else {
            return nil
        }

        // Visa: starts with 4
        if digitsOnly.hasPrefix("4") {
            return .visa
        }

        // Mastercard: starts with 51-55 or 2221-2720
        if let first2 = Int(String(digitsOnly.prefix(2))),
           (51...55).contains(first2) {
            return .mastercard
        }
        if let first4 = Int(String(digitsOnly.prefix(4))),
           (2221...2720).contains(first4) {
            return .mastercard
        }

        // American Express: starts with 34 or 37
        if digitsOnly.hasPrefix("34") || digitsOnly.hasPrefix("37") {
            return .americanExpress
        }

        // Discover: starts with 6011, 622126-622925, 644-649, or 65
        if digitsOnly.hasPrefix("6011") || digitsOnly.hasPrefix("65") {
            return .discover
        }
        if let first3 = Int(String(digitsOnly.prefix(3))),
           (644...649).contains(first3) {
            return .discover
        }
        if let first6 = Int(String(digitsOnly.prefix(6))),
           (622126...622925).contains(first6) {
            return .discover
        }

        // Diners Club: starts with 300-305, 36, 38-39
        if digitsOnly.hasPrefix("36") || digitsOnly.hasPrefix("38") || digitsOnly.hasPrefix("39") {
            return .dinersClub
        }
        if let first3 = Int(String(digitsOnly.prefix(3))),
           (300...305).contains(first3) {
            return .dinersClub
        }

        // JCB: starts with 3528-3589
        if let first4 = Int(String(digitsOnly.prefix(4))),
           (3528...3589).contains(first4) {
            return .jcb
        }

        // UnionPay: starts with 62
        if digitsOnly.hasPrefix("62") {
            return .unionPay
        }

        return nil
    }

    func makeCardNumberMask(from cardNumber: String?) -> String? {
        guard let cardNumber = cardNumber?.trim(), !cardNumber.isEmpty else {
            return nil
        }
        let digitsOnly = cardNumber.filter { $0.isNumber }
        guard digitsOnly.count >= 4 else {
            return nil
        }
        return String(digitsOnly.suffix(4))
    }
}

private extension CardItemInteractor {

    var selectedVaultId: VaultID {
        get throws(ItemsInteractorSaveError) {
            guard let vaultId = mainRepository.selectedVault?.vaultID else {
                throw .noVault
            }
            return vaultId
        }
    }

    func makeCard(
        id: ItemID,
        vaultId: VaultID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError) -> CardItemData {
        let protectionLevel = metadata.protectionLevel

        var encryptedCardNumber: Data?
        if let cardNumber = cardNumber?.trim(), !cardNumber.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(cardNumber, isSecureField: true, protectionLevel: protectionLevel) else {
                Log("CardItemInteractor: Can't encrypt cardNumber", module: .interactor, severity: .error)
                throw .encryptionError
            }
            encryptedCardNumber = encrypted
        }

        var encryptedExpirationDate: Data?
        if let expirationDate = expirationDate?.trim(), !expirationDate.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(expirationDate, isSecureField: true, protectionLevel: protectionLevel) else {
                Log("CardItemInteractor: Can't encrypt expirationDate", module: .interactor, severity: .error)
                throw .encryptionError
            }
            encryptedExpirationDate = encrypted
        }

        var encryptedSecurityCode: Data?
        if let securityCode = securityCode?.trim(), !securityCode.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(securityCode, isSecureField: true, protectionLevel: protectionLevel) else {
                Log("CardItemInteractor: Can't encrypt securityCode", module: .interactor, severity: .error)
                throw .encryptionError
            }
            encryptedSecurityCode = encrypted
        }

        let cardNumberMask = makeCardNumberMask(from: cardNumber)
        let cardIssuer = detectCardIssuer(from: cardNumber)?.rawValue

        return .init(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            content: .init(
                name: name,
                cardHolder: cardHolder?.trim().nilIfEmpty,
                cardIssuer: cardIssuer,
                cardNumber: encryptedCardNumber,
                cardNumberMask: cardNumberMask,
                expirationDate: encryptedExpirationDate,
                securityCode: encryptedSecurityCode,
                notes: notes?.trim().nilIfEmpty
            )
        )
    }
}
