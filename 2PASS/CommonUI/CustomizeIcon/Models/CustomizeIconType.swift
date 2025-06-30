// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

enum CustomizeIconType: CaseIterable, Hashable, Identifiable {
    var id: Self { self }
    case icon
    case label
    case custom
}

extension CustomizeIconType {
    var label: String {
        switch self {
        case .label: T.customizeIconLabelKey
        case .icon: T.customizeIconIcon
        case .custom: T.customizeIconCustom
        }
    }
    
    func toPasswordIconType(
        labelTitle: String,
        labelColor: UIColor?,
        iconDomain: String?,
        iconCustomURL: URL?
    ) -> PasswordIconType? {
        switch self {
        case .label:
            return PasswordIconType.label(labelTitle: labelTitle, labelColor: labelColor)
        case .icon:
            return PasswordIconType.domainIcon(iconDomain)
        case .custom:
            guard let iconCustomURL else { return nil }
            return PasswordIconType.customIcon(iconCustomURL)
        }
    }
}

extension PasswordIconType {
    func toCustomizeIconType() -> CustomizeIconType {
        switch self {
        case .domainIcon: .icon
        case .label: .label
        case .customIcon: .custom
        }
    }
}
