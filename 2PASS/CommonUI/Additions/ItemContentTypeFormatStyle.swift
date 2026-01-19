// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension FormatStyle where Self == ItemContentTypeFormatStyle {
    public static var itemContentType: ItemContentTypeFormatStyle {
        .init()
    }
}

extension ItemContentType {
    
    public func formatted() -> String {
        ItemContentTypeFormatStyle().format(self)
    }
}

public struct ItemContentTypeFormatStyle: FormatStyle {
    
    public func format(_ contentType: ItemContentType) -> String {
        switch contentType {
        case .login:
            return String(localized: .contentTypeLoginName)
        case .secureNote:
            return String(localized: .contentTypeSecureNoteName)
        case .paymentCard:
            return String(localized: .contentTypeCardName)
        case .unknown:
            return "Unknown"
        }
    }
}
