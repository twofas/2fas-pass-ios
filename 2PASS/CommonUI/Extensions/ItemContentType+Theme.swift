// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import UIKit

extension ItemContentType {
    
    public var iconSystemName: String? {
        switch self {
        case .login:
            return "person.crop.circle"
        case .secureNote:
            return "note.text"
        case .paymentCard:
            return "creditcard"
        case .unknown:
            return nil
        }
    }
    
    public var icon: UIImage? {
        let image: UIImage? = {
            let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            guard let iconSystemName else {
                return nil
            }
            return UIImage(systemName: iconSystemName, withConfiguration: configuration)
        }()
        return image?.withRenderingMode(.alwaysTemplate)
    }
    
    public var primaryColor: UIColor {
        switch self {
        case .login:
            UIColor(hexString: "#0088FF")!
        case .secureNote:
            UIColor(hexString: "#FF8D28")!
        case .paymentCard:
            UIColor(hexString: "#34C759")!
        case .unknown:
            .black
        }
    }
    
    public var secondaryColor: UIColor {
        switch self {
        case .login:
            UIColor(
                light: UIColor(hexString: "#D4EBFF")!,
                dark: UIColor(hexString: "#002B52")!
            )
        case .secureNote:
            UIColor(
                light: UIColor(hexString: "#FFF1E4")!,
                dark: UIColor(hexString: "#482709")!
            )
        case .paymentCard:
            UIColor(
                light: UIColor(hexString: "#D6FFE0")!,
                dark: UIColor(hexString: "#043B12")!
            )
        case .unknown:
            .black.withAlphaComponent(0.5)
        }
    }
}
