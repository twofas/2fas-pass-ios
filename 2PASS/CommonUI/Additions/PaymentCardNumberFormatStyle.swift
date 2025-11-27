// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension FormatStyle where Self == PaymentCardNumberFormatStyle {
    public static var paymentCardNumber: PaymentCardNumberFormatStyle {
        .init()
    }

    public static func paymentCardNumber(issuer: PaymentCardIssuer?) -> PaymentCardNumberFormatStyle {
        .init(issuer: issuer)
    }
}

public struct PaymentCardNumberFormatStyle: FormatStyle {

    private let issuer: PaymentCardIssuer?

    public init(issuer: PaymentCardIssuer? = nil) {
        self.issuer = issuer
    }

    public func format(_ value: String) -> String {
        guard value.isEmpty == false else {
            return ""
        }

        let digitsOnly = value.filter { $0.isNumber }
        guard digitsOnly.isEmpty == false else {
            return ""
        }

        let grouping = cardNumberGrouping(for: issuer, digitCount: digitsOnly.count)
        return formatWithGrouping(digitsOnly, grouping: grouping)
    }

    private func cardNumberGrouping(for issuer: PaymentCardIssuer?, digitCount: Int) -> [Int] {
        switch issuer {
        case .americanExpress:
            [4, 6, 5]
        case .dinersClub:
            [4, 6, 4]
        case .visa, .mastercard, .discover, .jcb, .unionPay:
            [4, 4, 4, 4, 3]
        case nil:
            [4, 4, 4, 4, 3]
        }
    }

    private func formatWithGrouping(_ digits: String, grouping: [Int]) -> String {
        var result = ""
        var currentIndex = digits.startIndex

        for (groupIndex, groupSize) in grouping.enumerated() {
            guard currentIndex < digits.endIndex else { break }

            let remainingCount = digits.distance(from: currentIndex, to: digits.endIndex)
            let actualGroupSize = min(groupSize, remainingCount)
            let endIndex = digits.index(currentIndex, offsetBy: actualGroupSize)

            if groupIndex > 0 {
                result.append(" ")
            }
            result.append(contentsOf: digits[currentIndex..<endIndex])
            currentIndex = endIndex
        }

        return result
    }
}
