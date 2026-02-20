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
        case .wifi:
            return "wifi"
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
            UIColor(light: UIColor(hexString: "#0087FF")!, dark: UIColor(hexString: "#00AFEF")!)
        case .secureNote:
            UIColor(light: UIColor(hexString: "#EDAC00")!, dark: UIColor(hexString: "#EDAC00")!)
        case .paymentCard:
            UIColor(light: UIColor(hexString: "#00C545")!, dark: UIColor(hexString: "#00C945")!)
        case .wifi:
            UIColor(light: UIColor(hexString: "#FF8500")!, dark: UIColor(hexString: "#FF8B00")!)
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
        case .wifi:
            UIColor(
                light: UIColor(hexString: "#FFEDD9")!,
                dark: UIColor(hexString: "#261500")!
            )
        case .unknown:
            .black.withAlphaComponent(0.5)
        }
    }
}
