// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import UIKit

extension PaymentCardIssuer {

    public var icon: UIImage {
        switch self {
        case .visa:
            return UIImage(resource: .visaIcon)
        case .mastercard:
            return UIImage(resource: .mastercardIcon)
        case .americanExpress:
            return UIImage(resource: .amexIcon)
        case .discover:
            return UIImage(resource: .discoverIcon)
        case .dinersClub:
            return UIImage(resource: .dinersclubIcon)
        case .jcb:
            return UIImage(resource: .jcbIcon)
        case .unionPay:
            return UIImage(resource: .unionpayIcon)
        }
    }
}

extension PaymentCardItemData {

    var issuerIcon: UIImage? {
        guard let issuerString = content.cardIssuer,
              let issuer = PaymentCardIssuer(rawValue: issuerString) else {
            return nil
        }
        return issuer.icon
    }
}
