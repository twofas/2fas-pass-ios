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
        case .microsoftEdge: "Microsoft Edge"
        case .enpass: "Enpass"
        case .keeper: "Keeper"
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .onePassword: [UTType.commaSeparatedText, UTType.zip]
        case .bitWarden: [UTType.json, UTType.commaSeparatedText]
        case .chrome: [UTType.commaSeparatedText]
        case .dashlaneDesktop: [UTType.zip]
        case .dashlaneMobile: [UTType.commaSeparatedText, UTType.folder]
        case .lastPass: [UTType.commaSeparatedText]
        case .protonPass: [UTType.commaSeparatedText, UTType.zip]
        case .applePasswordsDesktop: [UTType.commaSeparatedText]
        case .applePasswordsMobile: [UTType.zip]
        case .firefox: [UTType.commaSeparatedText]
        case .keePassXC: [UTType.commaSeparatedText]
        case .keePass: [UTType.commaSeparatedText, UTType.xml]
        case .microsoftEdge: [UTType.commaSeparatedText]
        case .enpass: [UTType.json]
        case .keeper: [UTType.json]
        }
    }
}
