// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI
import UIKit

extension ItemProtectionLevel {

    public var icon: Image {
        Image(uiImage: uiIcon)
    }

    public var uiIcon: UIImage {
        switch self {
        case .normal:
            UIImage(resource: .tier3Icon)
        case .confirm:
            UIImage(resource: .tier2Icon)
        case .topSecret:
            UIImage(resource: .tier1Icon)
        }
    }
}
