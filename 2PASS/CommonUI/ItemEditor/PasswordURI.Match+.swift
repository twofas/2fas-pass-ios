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
        case .domain: T.loginUriMatcherDomainTitle
        case .host: T.loginUriMatcherHostTitle
        case .startsWith: T.loginUriMatcherStartsWithTitle
        case .exact: T.loginUriMatcherExactTitle
        }
    }
    
    var description: String {
        switch self {
        case .domain: T.loginUriMatcherDomainDescription
        case .host: T.loginUriMatcherHostDescription
        case .startsWith: T.loginUriMatcherStartsWithDescription
        case .exact: T.loginUriMatcherExactDescription
        }
    }
}
