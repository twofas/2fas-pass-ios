// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

public protocol PaymentCardUtilityInteracting: AnyObject {
    func detectCardIssuer(from cardNumber: String?) -> PaymentCardIssuer?
    func maxCardNumberLength(for issuer: PaymentCardIssuer?) -> Int
    func maxSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int
    func minCardNumberLength(for issuer: PaymentCardIssuer?) -> Int
    func cardNumberMask(from cardNumber: String?) -> String?
    func validateExpirationDate(_ value: String) -> Bool
    func validateSecurityCode(_ value: String, for issuer: PaymentCardIssuer?) -> Bool
    func validateCardNumber(_ value: String, for issuer: PaymentCardIssuer?) -> Bool
}

public final class PaymentCardUtilityInteractor: PaymentCardUtilityInteracting {

    public init() {}

    public func maxCardNumberLength(for issuer: PaymentCardIssuer?) -> Int {
        switch issuer {
        case .visa, .mastercard, .jcb:
            return 16
        case .americanExpress:
            return 15
        case .discover, .dinersClub, .unionPay:
            return 19
        case nil:
            return 19
        }
    }

    public func minCardNumberLength(for issuer: PaymentCardIssuer?) -> Int {
        switch issuer {
        case .visa, .mastercard, .jcb:
            return 16
        case .americanExpress:
            return 15
        case .dinersClub:
            return 14
        case .discover, .unionPay:
            return 16
        case nil:
            return 13
        }
    }

    public func maxSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int {
        switch issuer {
        case .americanExpress, nil:
            return 4
        case .visa, .mastercard, .discover, .dinersClub, .jcb, .unionPay:
            return 3
        }
    }

    public func detectCardIssuer(from cardNumber: String?) -> PaymentCardIssuer? {
        guard let cardNumber = cardNumber?.trim(), !cardNumber.isEmpty else {
            return nil
        }
        let digitsOnly = cardNumber.filter { $0.isNumber }

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

    public func cardNumberMask(from cardNumber: String?) -> String? {
        guard let cardNumber = cardNumber?.trim(), !cardNumber.isEmpty else {
            return nil
        }
        let digitsOnly = cardNumber.filter { $0.isNumber }
        return String(digitsOnly.suffix(4))
    }

    public func validateExpirationDate(_ value: String) -> Bool {
        let components = value.split(separator: "/")
        guard components.count == 2,
              let month = Int(components[0]),
              components[0].count == 2,
              components[1].count == 2 else {
            return false
        }
        return month >= 1 && month <= 12
    }

    public func validateSecurityCode(_ value: String, for issuer: PaymentCardIssuer?) -> Bool {
        let digitsOnly = value.filter { $0.isNumber }
        guard digitsOnly.count == value.count else { return false }

        let expectedLength = maxSecurityCodeLength(for: issuer)
        if issuer != nil {
            return value.count == expectedLength
        } else {
            return (3...4).contains(value.count)
        }
    }

    public func validateCardNumber(_ value: String, for issuer: PaymentCardIssuer?) -> Bool {
        guard value.allSatisfy({ $0.isNumber || $0.isWhitespace }) else { return false}

        let digitsOnly = value.filter { $0.isNumber }
        let minLength = minCardNumberLength(for: issuer)
        let maxLength = maxCardNumberLength(for: issuer)
        guard digitsOnly.count >= minLength && digitsOnly.count <= maxLength else { return false }

        return luhnCheck(digitsOnly)
    }

    private func luhnCheck(_ cardNumber: String) -> Bool {
        let digits = cardNumber.compactMap { $0.wholeNumberValue }
        guard digits.count == cardNumber.count else { return false }

        var sum = 0
        for (index, digit) in digits.reversed().enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }
}
