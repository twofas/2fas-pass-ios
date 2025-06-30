// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import SVGView

private struct Constants {
    static let identiconSize = 32.0
    static let identiconPlaceholderSize = 64.0
    static let identiconPlaceholderCornerRadius = 16.0
    static let identiconPlaceholderBorderLineWidth = 0.5
    
    static let identiconPlaceholderShadowOpacity = 0.04
    static let identiconPlaceholderShadowRadius = 20.0
    static let identiconPlaceholderShadowOffsetY = 12.0
}

struct ConnectIdenticonView: View {
    
    let identicon: String?
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: Constants.identiconPlaceholderCornerRadius)
            .fill(colorScheme == .dark ? .neutral50 : .base0)
            .stroke(colorScheme == .dark ? .neutral200 : .neutral100, lineWidth: Constants.identiconPlaceholderBorderLineWidth)
            .overlay {
                if let identicon {
                    SVGView(string: identicon)
                        .frame(width: Constants.identiconSize, height: Constants.identiconSize)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: Constants.identiconPlaceholderCornerRadius)
                    .padding(1)
                    .shadow(color: .black.opacity(Constants.identiconPlaceholderShadowOpacity), radius: Constants.identiconPlaceholderShadowRadius, x: 0, y: Constants.identiconPlaceholderShadowOffsetY)
            }
            .frame(width: Constants.identiconPlaceholderSize, height: Constants.identiconPlaceholderSize)
    }
}
