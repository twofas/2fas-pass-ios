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
            return T.contentTypeFilterAllName
        case .contentType(.login):
            return T.contentTypeFilterLoginName
        case .contentType(.secureNote):
            return T.contentTypeFilterSecureNoteName
        case .contentType(.card):
            return T.contentTypeFilterCardName
        case .contentType(.unknown):
            return "Unknows"
        }
    }
}
