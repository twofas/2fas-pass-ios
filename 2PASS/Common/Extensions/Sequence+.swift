// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public extension Sequence where Element == UInt8 {
    func toHEXString() -> String {
        map { String(format: "%02x", $0) }.joined()
    }
}
