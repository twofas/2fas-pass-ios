// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension FormatStyle where Self == ItemNameFormatStyle {
    public static var itemName: ItemNameFormatStyle {
        .init()
    }
}

public struct ItemNameFormatStyle: FormatStyle {
    
    public init() {}
    
    public func format(_ value: String?) -> String {
        guard let value else {
            return T.loginNoItemName
        }
        return value.isEmpty ? T.loginNoItemName : value
    }
}
