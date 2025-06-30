// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import CommonUI

extension RecoveryKitPDFConfig {
    static var `default`: RecoveryKitPDFConfig {
        .init(
            wordsSpacing: Spacing.m,
            lineHeight: Spacing.m,
            logo: Asset._2PASSLogoRecoveryKit.image,
            qrCodeLogo: Asset._2PASSShieldRecoveryKit.image
        )
    }
}
