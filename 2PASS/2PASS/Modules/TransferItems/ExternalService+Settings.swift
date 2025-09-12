// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension ExternalService {
    
    var settingsIcon: SettingsIcon {
        switch self {
        case .onePassword: .onePassword
        case .bitWarden: .bitwarden
        case .chrome: .chrome
        case .dashlaneMobile, .dashlaneDesktop: .dashlane
        case .lastPass: .lastPass
        case .protonPass: .proton
        case .applePasswordsDesktop, .applePasswordsMobile: .applePasswords
        case .firefox: .firefox
        case .keePass: .keePass
        case .keePassXC: .keePassXC
        }
    }
}
