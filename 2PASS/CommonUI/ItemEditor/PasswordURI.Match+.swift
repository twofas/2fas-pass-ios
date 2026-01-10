// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension PasswordURI.Match {
    var title: String {
        switch self {
        case .domain: String(localized: .loginUriMatcherDomainTitle)
        case .host: String(localized: .loginUriMatcherHostTitle)
        case .startsWith: String(localized: .loginUriMatcherStartsWithTitle)
        case .exact: String(localized: .loginUriMatcherExactTitle)
        }
    }
    
    var description: String {
        switch self {
        case .domain: String(localized: .loginUriMatcherDomainDescription)
        case .host: String(localized: .loginUriMatcherHostDescription)
        case .startsWith: String(localized: .loginUriMatcherStartsWithDescription)
        case .exact: String(localized: .loginUriMatcherExactDescription)
        }
    }
}
