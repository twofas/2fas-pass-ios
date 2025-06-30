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
            title: T.recoveryKitTitle,
            author: T.recoveryKitAuthor,
            creator: T.recoveryKitCreator,
            header: T.recoveryKitHeader,
            writeDown: T.recoveryKitWriteDown
        )
    }
}
