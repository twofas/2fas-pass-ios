// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

struct CustomizeIconData {
    let name: String
    let labelTitle: String
    let labelColor: UIColor?
    let iconCustomURL: URL?
    let iconDomain: String?
    let uriDomains: [String]
    let currentIconType: PasswordIconType
    
    init(currentIconType: PasswordIconType, name: String, passwordName: String, uriDomains: [String]) {
        self.name = name
        self.currentIconType = currentIconType
        self.uriDomains = uriDomains
        
        let passwordName: String = {
            guard passwordName.trim().count > 0 else {
                return Config.defaultIconLabel
            }
            return passwordName.twoLetters
        }()
        
        switch currentIconType {
        case .domainIcon(let domain):
            self.labelTitle = passwordName.twoLetters
            self.labelColor = nil
            self.iconDomain = domain
            self.iconCustomURL = nil
        case .customIcon(let iconURI):
            self.labelTitle = passwordName.twoLetters
            self.labelColor = nil
            self.iconDomain = nil
            self.iconCustomURL = iconURI
        case .label(let labelTitle, let labelColor):
            self.labelTitle = labelTitle
            self.labelColor = labelColor
            self.iconDomain = nil
            self.iconCustomURL = nil
        }
    }
    
    var current: PasswordIconType {
        currentIconType
    }
}
