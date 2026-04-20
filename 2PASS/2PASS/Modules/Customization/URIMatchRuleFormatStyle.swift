// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct URIMatchRuleFormatStyle: FormatStyle {

    func format(_ rule: PasswordURI.Match) -> String {
        switch rule {
        case .domain:
            String(localized: .loginUriMatcherDomainTitle)
        case .host:
            String(localized: .loginUriMatcherHostTitle)
        case .startsWith:
            String(localized: .loginUriMatcherStartsWithTitle)
        case .exact:
            String(localized: .loginUriMatcherExactTitle)
        }
    }
}
