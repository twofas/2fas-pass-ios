// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

enum SocialChannel: CaseIterable {
    case discord
    case youtube
    case twitter
    case github
    
    var image: Image {
        switch self {
        case .discord: Image(.socialDiscord)
        case .youtube: Image(.socialYoutube)
        case .twitter: Image(.socialTwitter)
        case .github: Image(.socialGithub)
        }
    }
    
    var url: URL {
        switch self {
        case .discord:
            return URL(string: "https://2fas.com/discord")!
        case .youtube:
            return URL(string: "https://www.youtube.com/@2fas")!
        case .twitter:
            return URL(string: "https://twitter.com/2fas_com")!
        case .github:
            return URL(string: "https://github.com/twofas")!
        }
    }
    
    var name: String {
        switch self {
        case .discord: return "Discord"
        case .youtube: return "YouTube"
        case .twitter: return "X"
        case .github: return "GitHub"
        }
    }
}
