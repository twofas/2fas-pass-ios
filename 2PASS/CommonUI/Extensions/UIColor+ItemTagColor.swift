// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public extension UIColor {
    convenience init(_ tagColor: ItemTagColor) {
        switch tagColor {
        case .red:
            self.init(light: UIColor(hexString: "#FF383C")!, dark: UIColor(hexString: "#FF4245")!)
        case .orange:
            self.init(light: UIColor(hexString: "#FF8D28")!, dark: UIColor(hexString: "#FF9230")!)
        case .yellow:
            self.init(light: UIColor(hexString: "#FFCC00")!, dark: UIColor(hexString: "#FFD600")!)
        case .green:
            self.init(light: UIColor(hexString: "#34C759")!, dark: UIColor(hexString: "#30D158")!)
        case .cyan:
            self.init(light: UIColor(hexString: "#00C0E8")!, dark: UIColor(hexString: "#3CD3FE")!)
        case .indigo:
            self.init(light: UIColor(hexString: "#6155F5")!, dark: UIColor(hexString: "#6D7CFF")!)
        case .purple:
            self.init(light: UIColor(hexString: "#CB30E0")!, dark: UIColor(hexString: "#DB34F2")!)
        case .gray, .unknown:
            self.init(light: UIColor(hexString: "#AEAEB2")!, dark: UIColor(hexString: "#636366")!)
        }
    }
}
