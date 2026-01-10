// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

extension RecoveryKitTranslations {
    static var `default`: RecoveryKitTranslations {
        RecoveryKitTranslations(
            title: String(localized: .recoveryKitTitle),
            author: String(localized: .recoveryKitAuthor),
            creator: String(localized: .recoveryKitCreator),
            header: String(localized: .recoveryKitHeader),
            writeDown: String(localized: .recoveryKitWriteDown)
        )
    }
}
