// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol PaymentCardItemInteracting: AnyObject {

    func createPaymentCard(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError)

    func updatePaymentCard(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError)
}

final class PaymentCardItemInteractor {
    private let itemsInteractor: ItemsInteracting
    private let mainRepository: MainRepository
    private let paymentCardUtilityInteractor: PaymentCardUtilityInteracting

    init(
        itemsInteractor: ItemsInteracting,
        mainRepository: MainRepository,
        paymentCardUtilityInteractor: PaymentCardUtilityInteracting
    ) {
        self.itemsInteractor = itemsInteractor
        self.mainRepository = mainRepository
        self.paymentCardUtilityInteractor = paymentCardUtilityInteractor
    }
}

extension PaymentCardItemInteractor: PaymentCardItemInteracting {

    func createPaymentCard(
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
        let paymentCardItem = try makePaymentCard(
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
        try itemsInteractor.createItem(.paymentCard(paymentCardItem))
    }

    func updatePaymentCard(
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
        let paymentCardItem = try makePaymentCard(
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
        try itemsInteractor.updateItem(.paymentCard(paymentCardItem))
    }
}

private extension PaymentCardItemInteractor {

    var selectedVaultId: VaultID {
        get throws(ItemsInteractorSaveError) {
            guard let vaultId = mainRepository.selectedVault?.vaultID else {
                throw .noVault
            }
            return vaultId
        }
    }

    func makePaymentCard(
        id: ItemID,
        vaultId: VaultID,
        metadata: ItemMetadata,
        name: String,
        cardHolder: String?,
        cardNumber: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) throws(ItemsInteractorSaveError) -> PaymentCardItemData {
        let protectionLevel = metadata.protectionLevel

        var encryptedCardNumber: Data?
        if let cardNumber = cardNumber?.trim(), !cardNumber.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(cardNumber, isSecureField: true, protectionLevel: protectionLevel) else {
                Log("PaymentCardItemInteractor: Can't encrypt cardNumber", module: .interactor, severity: .error)
                throw .encryptionError
            }
            encryptedCardNumber = encrypted
        }

        var encryptedExpirationDate: Data?
        if let expirationDate = expirationDate?.trim(), !expirationDate.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(expirationDate, isSecureField: true, protectionLevel: protectionLevel) else {
                Log("PaymentCardItemInteractor: Can't encrypt expirationDate", module: .interactor, severity: .error)
                throw .encryptionError
            }
            encryptedExpirationDate = encrypted
        }

        var encryptedSecurityCode: Data?
        if let securityCode = securityCode?.trim(), !securityCode.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(securityCode, isSecureField: true, protectionLevel: protectionLevel) else {
                Log("PaymentCardItemInteractor: Can't encrypt securityCode", module: .interactor, severity: .error)
                throw .encryptionError
            }
            encryptedSecurityCode = encrypted
        }

        let cardNumberMask = paymentCardUtilityInteractor.cardNumberMask(from: cardNumber)
        let paymentCardIssuer = paymentCardUtilityInteractor.detectCardIssuer(from: cardNumber)?.rawValue

        return .init(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            content: .init(
                name: name,
                cardHolder: cardHolder?.trim().nilIfEmpty,
                cardIssuer: paymentCardIssuer,
                cardNumber: encryptedCardNumber,
                cardNumberMask: cardNumberMask,
                expirationDate: encryptedExpirationDate,
                securityCode: encryptedSecurityCode,
                notes: notes?.trim().nilIfEmpty
            )
        )
    }
}
