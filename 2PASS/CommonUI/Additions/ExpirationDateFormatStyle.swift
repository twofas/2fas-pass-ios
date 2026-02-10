// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension FormatStyle where Self == ExpirationDateFormatStyle {
    public static var expirationDate: ExpirationDateFormatStyle {
        .init()
    }
}

public struct ExpirationDateFormatStyle: FormatStyle {
    public init() {}

    public func format(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return trimmed }
        let month = parts[0].trimmingCharacters(in: .whitespaces)
        let year = parts[1].trimmingCharacters(in: .whitespaces)
        return month.isEmpty && year.isEmpty ? "" : "\(month) / \(year)"
    }
}
