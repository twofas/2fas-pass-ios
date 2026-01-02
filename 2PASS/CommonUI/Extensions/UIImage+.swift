// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public extension UIImage {
    static func circleImage(
        color: UIColor,
        size: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.fillEllipse(in: rect)
        }
    }
}
