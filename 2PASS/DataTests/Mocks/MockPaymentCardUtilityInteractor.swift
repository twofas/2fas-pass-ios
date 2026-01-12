// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

final class MockPaymentCardUtilityInteractor: PaymentCardUtilityInteracting {

    // MARK: - Call Tracking

    private(set) var methodCalls: [String] = []

    private func recordCall(_ name: String = #function) {
        methodCalls.append(name)
    }

    func resetCalls() {
        methodCalls.removeAll()
    }

    func wasCalled(_ method: String) -> Bool {
        methodCalls.contains(method)
    }

    func callCount(_ method: String) -> Int {
        methodCalls.filter { $0 == method }.count
    }

    // MARK: - Stubbed Properties

    private var stubbedDetectCardIssuer: (String?) -> PaymentCardIssuer? = { _ in nil }
    private var stubbedMaxCardNumberLength: (PaymentCardIssuer?) -> Int = { _ in 19 }
    private var stubbedMaxSecurityCodeLength: (PaymentCardIssuer?) -> Int = { _ in 4 }
    private var stubbedMinCardNumberLength: (PaymentCardIssuer?) -> Int = { _ in 13 }
    private var stubbedCardNumberMask: (String?) -> String? = { _ in nil }
    private var stubbedValidateExpirationDate: (String) -> Bool = { _ in true }
    private var stubbedValidateSecurityCode: (String, PaymentCardIssuer?) -> Bool = { _, _ in true }
    private var stubbedValidateCardNumber: (String, PaymentCardIssuer?) -> Bool = { _, _ in true }

    // MARK: - Stub Configuration

    @discardableResult
    func withDetectCardIssuer(_ handler: @escaping (String?) -> PaymentCardIssuer?) -> Self {
        stubbedDetectCardIssuer = handler
        return self
    }

    @discardableResult
    func withMaxCardNumberLength(_ handler: @escaping (PaymentCardIssuer?) -> Int) -> Self {
        stubbedMaxCardNumberLength = handler
        return self
    }

    @discardableResult
    func withMaxSecurityCodeLength(_ handler: @escaping (PaymentCardIssuer?) -> Int) -> Self {
        stubbedMaxSecurityCodeLength = handler
        return self
    }

    @discardableResult
    func withMinCardNumberLength(_ handler: @escaping (PaymentCardIssuer?) -> Int) -> Self {
        stubbedMinCardNumberLength = handler
        return self
    }

    @discardableResult
    func withCardNumberMask(_ handler: @escaping (String?) -> String?) -> Self {
        stubbedCardNumberMask = handler
        return self
    }

    @discardableResult
    func withValidateExpirationDate(_ handler: @escaping (String) -> Bool) -> Self {
        stubbedValidateExpirationDate = handler
        return self
    }

    @discardableResult
    func withValidateSecurityCode(_ handler: @escaping (String, PaymentCardIssuer?) -> Bool) -> Self {
        stubbedValidateSecurityCode = handler
        return self
    }

    @discardableResult
    func withValidateCardNumber(_ handler: @escaping (String, PaymentCardIssuer?) -> Bool) -> Self {
        stubbedValidateCardNumber = handler
        return self
    }

    // MARK: - PaymentCardUtilityInteracting

    func detectCardIssuer(from cardNumber: String?) -> PaymentCardIssuer? {
        recordCall()
        return stubbedDetectCardIssuer(cardNumber)
    }

    func maxCardNumberLength(for issuer: PaymentCardIssuer?) -> Int {
        recordCall()
        return stubbedMaxCardNumberLength(issuer)
    }

    func maxSecurityCodeLength(for issuer: PaymentCardIssuer?) -> Int {
        recordCall()
        return stubbedMaxSecurityCodeLength(issuer)
    }

    func minCardNumberLength(for issuer: PaymentCardIssuer?) -> Int {
        recordCall()
        return stubbedMinCardNumberLength(issuer)
    }

    func cardNumberMask(from cardNumber: String?) -> String? {
        recordCall()
        return stubbedCardNumberMask(cardNumber)
    }

    func validateExpirationDate(_ value: String) -> Bool {
        recordCall()
        return stubbedValidateExpirationDate(value)
    }

    func validateSecurityCode(_ value: String, for issuer: PaymentCardIssuer?) -> Bool {
        recordCall()
        return stubbedValidateSecurityCode(value, issuer)
    }

    func validateCardNumber(_ value: String, for issuer: PaymentCardIssuer?) -> Bool {
        recordCall()
        return stubbedValidateCardNumber(value, issuer)
    }
}
