// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public enum PaymentCardIssuer: String, Codable, Hashable, Sendable {
    case visa = "Visa"
    case mastercard = "MC"
    case americanExpress = "AMEX"
    case discover = "Discover"
    case dinersClub = "DinersClub"
    case jcb = "JCB"
    case unionPay = "UnionPay"
}
