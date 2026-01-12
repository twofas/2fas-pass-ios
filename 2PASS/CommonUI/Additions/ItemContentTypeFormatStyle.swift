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

public struct ItemContentTypeFormatStyle: FormatStyle {
    
    public func format(_ contentType: ItemContentType) -> String {
        switch contentType {
        case .login:
            return T.contentTypeLoginName
        case .secureNote:
            return T.contentTypeSecureNoteName
        case .paymentCard:
            return T.contentTypeCardName
        case .unknown:
            return "Unknown"
        }
    }
}
