// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import UniformTypeIdentifiers

public extension ExternalService {
    var name: String {
        switch self {
        case .onePassword: "1Password"
        case .bitWarden: "BitWarden"
        case .chrome: "Chrome"
        case .dashlaneMobile: "Dashlane Mobile"
        case .dashlaneDesktop: "Dashlane Desktop"
        case .lastPass: "LastPass"
        case .protonPass: "Proton Pass"
        case .applePasswordsDesktop: "Apple Passwords Desktop"
        case .applePasswordsMobile: "Apple Passwords Mobile"
        case .firefox: "Firefox"
        case .keePassXC: "KeePassXC"
        case .keePass: "KeePass"
        }
    }
    
    var allowedContentType: UTType {
        switch self {
        case .onePassword: UTType.commaSeparatedText
        case .bitWarden: UTType.json
        case .chrome: UTType.commaSeparatedText
        case .dashlaneDesktop: UTType.zip
        case .dashlaneMobile: UTType.commaSeparatedText
        case .lastPass: UTType.commaSeparatedText
        case .protonPass: UTType.commaSeparatedText
        case .applePasswordsDesktop: UTType.commaSeparatedText
        case .applePasswordsMobile: UTType.zip
        case .firefox: UTType.commaSeparatedText
        case .keePassXC: UTType.commaSeparatedText
        case .keePass: UTType.commaSeparatedText
        }
    }
}
