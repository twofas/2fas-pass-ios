// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension Color {
    static let backgroundPrimary = Color(uiColor: .backgroundPrimary)
    static let backgroundSecondary = Color(uiColor: .backgroundSecondary)
    static let backgroundTertiary = Color(uiColor: .backgroundTertiary)
}

extension Color {
    init(light lightModeColor: @escaping @autoclosure () -> Color, dark darkModeColor: @escaping @autoclosure () -> Color) {
        self.init(uiColor: UIColor(
            light: UIColor(lightModeColor()),
            dark: UIColor(darkModeColor())
        ))
    }
}
