// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import UIKit

extension ItemContentType {
    
    public var icon: UIImage? {
        let image: UIImage? = {
            let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)
            
            switch self {
            case .login, .unknown:
                return UIImage(systemName: "person.crop.circle", withConfiguration: configuration)
            case .secureNote:
                return UIImage(systemName: "note.text", withConfiguration: configuration)
            }
        }()
        return image?.withRenderingMode(.alwaysTemplate)
    }
    
    public var iconColor: UIColor? {
        switch self {
        case .login, .unknown:
            return .baseStatic0
        case .secureNote:
            return UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(hexString: "#3CD3FE")!
                } else {
                    return UIColor(hexString: "#00B2E1")!
                }
            }
        }
    }
    
    public var iconBackgroundColor: UIColor {
        switch self {
        case .login:
            return UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(hexString: "#FF8400")!
                } else {
                    return UIColor(hexString: "#E97900")!
                }
            }
        case .unknown:
            return .black
        case .secureNote:
            return UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(hexString: "#1E455B")!
                } else {
                    return UIColor(hexString: "#DCF0FB")!
                }
            }
        }
    }
}
