// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public final class PastelColors {
    private static let colors: [UIColor] = [
        UIColor(red: 0.69, green: 0.89, blue: 0.80, alpha: 1.0),
        UIColor(red: 0.78, green: 0.85, blue: 0.94, alpha: 1.0),
        UIColor(red: 0.98, green: 0.80, blue: 0.69, alpha: 1.0),
        UIColor(red: 0.85, green: 0.76, blue: 0.93, alpha: 1.0),
        UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1.0),
        UIColor(red: 0.93, green: 0.73, blue: 0.82, alpha: 1.0),
        UIColor(red: 0.75, green: 0.87, blue: 0.73, alpha: 1.0),
        UIColor(red: 0.91, green: 0.78, blue: 0.65, alpha: 1.0),
        UIColor(red: 0.71, green: 0.80, blue: 0.89, alpha: 1.0),
        UIColor(red: 0.94, green: 0.80, blue: 0.86, alpha: 1.0),
        UIColor(red: 0.82, green: 0.91, blue: 0.84, alpha: 1.0),
        UIColor(red: 0.96, green: 0.84, blue: 0.79, alpha: 1.0),
        UIColor(red: 0.78, green: 0.78, blue: 0.87, alpha: 1.0),
        UIColor(red: 0.89, green: 0.85, blue: 0.71, alpha: 1.0),
        UIColor(red: 0.87, green: 0.76, blue: 0.74, alpha: 1.0),
        UIColor(red: 0.73, green: 0.85, blue: 0.85, alpha: 1.0),
        UIColor(red: 0.93, green: 0.82, blue: 0.73, alpha: 1.0),
        UIColor(red: 0.80, green: 0.87, blue: 0.89, alpha: 1.0),
        UIColor(red: 0.91, green: 0.85, blue: 0.91, alpha: 1.0),
        UIColor(red: 0.85, green: 0.89, blue: 0.76, alpha: 1.0)
    ]
    
    public static func random() -> UIColor {
        colors[Int.random(in: 0..<colors.count)]
    }
}
