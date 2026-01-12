// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemDetailFormProtectionLevel: View {
    
    let protectionLevel: ItemProtectionLevel
    
    init(_ protectionLevel: ItemProtectionLevel) {
        self.protectionLevel = protectionLevel
    }
    
    var body: some View {
        LabeledContent(String(localized: .loginSecurityLevelLabel)) {
            ProtectionLevelLabel(protectionLevel)
        }
        .labeledContentStyle(.listCell)
    }
}
