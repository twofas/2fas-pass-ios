// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import UIKit

extension PaymentCardIssuer {

    public var icon: UIImage {
        UIImage(resource: iconResource)
    }
    
    private var iconResource: ImageResource {
        switch self {
        case .visa:
            return .visaIcon
        case .mastercard:
            return .mastercardIcon
        case .americanExpress:
            return .amexIcon
        case .discover:
            return .discoverIcon
        case .dinersClub:
            return .dinersclubIcon
        case .jcb:
            return .jcbIcon
        case .unionPay:
            return .unionpayIcon
        }
    }
}

public extension PaymentCardItemData {

    var issuerIcon: UIImage? {
        guard let issuerString = content.cardIssuer,
              let issuer = PaymentCardIssuer(rawValue: issuerString) else {
            return nil
        }
        return issuer.icon
    }
}
