// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public typealias PaymentCardItemData          = _ItemData<PaymentCardContent>
public typealias PaymentCardItemDecryptedData = _ItemData<PaymentCardDecryptedContent>

public typealias PaymentCardContent          = _PaymentCardContent<Encrypted>
public typealias PaymentCardDecryptedContent = _PaymentCardContent<Decrypted>

public struct _PaymentCardContent<State: EncryptionState>: ItemContent {

    public static var contentType: ItemContentType { .paymentCard }
    public static var contentVersion: Int { 1 }

    public let name: String?
    public let cardHolder: String?
    public let cardIssuer: String?
    public let cardNumber: State.SecureField?
    public let cardNumberMask: String?
    public let expirationDate: State.SecureField?
    public let securityCode: State.SecureField?
    public let notes: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case cardHolder
        case cardNumber = "s_cardNumber"
        case expirationDate = "s_expirationDate"
        case securityCode = "s_securityCode"
        case notes
        case cardNumberMask
        case cardIssuer
    }
}

extension PaymentCardContent {

    public init(
        name: String?,
        cardHolder: String?,
        cardIssuer: String?,
        cardNumber: Data?,
        cardNumberMask: String?,
        expirationDate: Data?,
        securityCode: Data?,
        notes: String?
    ) {
        self.name = name
        self.cardHolder = cardHolder
        self.cardNumber = cardNumber
        self.expirationDate = expirationDate
        self.securityCode = securityCode
        self.notes = notes
        self.cardNumberMask = cardNumberMask
        self.cardIssuer = cardIssuer
    }
}

extension PaymentCardDecryptedContent {

    public init(
        name: String?,
        cardHolder: String?,
        cardIssuer: String?,
        cardNumber: String?,
        cardNumberMask: String?,
        expirationDate: String?,
        securityCode: String?,
        notes: String?
    ) {
        self.name = name
        self.cardHolder = cardHolder
        self.cardNumber = cardNumber
        self.expirationDate = expirationDate
        self.securityCode = securityCode
        self.notes = notes
        self.cardNumberMask = cardNumberMask
        self.cardIssuer = cardIssuer
    }
}

extension ItemData {

    public var asPaymentCard: PaymentCardItemData? {
        switch self {
        case .paymentCard(let paymentCardItem): paymentCardItem
        default: nil
        }
    }
}

extension ItemDecryptedData {

    public var asPaymentCard: PaymentCardItemDecryptedData? {
        switch self {
        case .paymentCard(let paymentCardItem): paymentCardItem
        default: nil
        }
    }
}
