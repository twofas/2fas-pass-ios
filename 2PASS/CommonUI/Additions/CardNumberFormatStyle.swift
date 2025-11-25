// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension FormatStyle where Self == CardNumberFormatStyle {
    public static var cardNumber: CardNumberFormatStyle {
        .init()
    }
}

public struct CardNumberFormatStyle: FormatStyle {

    public init() {}

    public func format(_ value: String) -> String {
        guard value.isEmpty == false else {
            return ""
        }

        let digitsOnly = value.filter { $0.isNumber }
        guard digitsOnly.isEmpty == false else {
            return ""
        }

        var result = ""
        for (index, character) in digitsOnly.enumerated() {
            if index > 0 && index % 4 == 0 {
                result.append(" ")
            }
            result.append(character)
        }

        return result
    }
}
