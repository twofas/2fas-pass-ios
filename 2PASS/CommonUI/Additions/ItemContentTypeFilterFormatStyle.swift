// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

extension FormatStyle where Self == ItemContentTypeFilterFormatStyle {
    static var itemContentTypeFilter: ItemContentTypeFilterFormatStyle {
        .init()
    }
}

struct ItemContentTypeFilterFormatStyle: FormatStyle {

    func format(_ filter: ItemContentTypeFilter) -> String {
        switch filter {
        case .all:
            return String(localized: .contentTypeFilterAllName)
        case .contentType(.login):
            return String(localized: .contentTypeFilterLoginName)
        case .contentType(.secureNote):
            return String(localized: .contentTypeFilterSecureNoteName)
        case .contentType(.paymentCard):
            return String(localized: .contentTypeFilterCardName)
        case .contentType(.wifi):
            return String(localized: .contentTypeWifiName)
        case .contentType(.unknown):
            return String(localized: .contentTypeUnknownName)
        }
    }
}
