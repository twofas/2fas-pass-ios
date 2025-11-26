// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension FormatStyle where Self == PaymentCardNumberMaskFormatStyle {
    public static var paymentCardNumberMask: PaymentCardNumberMaskFormatStyle {
        .init()
    }
}

public struct PaymentCardNumberMaskFormatStyle: FormatStyle {

    public init() {}

    public func format(_ value: String) -> String {
        guard value.isEmpty == false else {
            return ""
        }

        return "•••• \(value.suffix(4))"
    }
}
