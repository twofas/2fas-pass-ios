// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct PasswordListActionFormatStyle: FormatStyle {
    
    func format(_ action: PasswordListAction) -> String {
        switch action {
        case .copy:
            T.loginViewActionCommonCopy
        case .edit:
            T.loginEdit
        case .viewDetails:
            T.loginViewActionViewDetails
        case .goToURI:
            T.loginViewActionOpenUri
        }
    }
}
