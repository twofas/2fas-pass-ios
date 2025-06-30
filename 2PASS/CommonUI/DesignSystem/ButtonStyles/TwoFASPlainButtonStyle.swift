// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension ButtonStyle where Self == TwoFASButtonStyle {
    
    static var twofasPlain: TwoFASPlainButtonStyle {
        TwoFASPlainButtonStyle()
    }
}

public struct TwoFASPlainButtonStyle: ButtonStyle {
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
