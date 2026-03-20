// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

private final class CommonUIBundleToken {}

extension Bundle {
    public static let commonUI = Bundle(for: CommonUIBundleToken.self)
}
