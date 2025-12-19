// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension Array where Element == String {
    func containsAll(_ elements: [String]) -> Bool {
        elements.allSatisfy { self.contains($0) }
    }
}

extension Dictionary where Key == String, Value == String {
    var allValuesEmpty: Bool {
        allSatisfy { $0.value.isEmpty }
    }
}
