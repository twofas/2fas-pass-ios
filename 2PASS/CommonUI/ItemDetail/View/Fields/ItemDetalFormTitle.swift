// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ItemDetalFormTitle: View {
    
    let name: String
    let icon: IconContent?
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            IconRendererView(content: icon)
            
            Text(name, format: .itemName)
                .font(.title3Emphasized)
                .foregroundStyle(.neutral950)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .padding([.vertical], Spacing.xs)
    }
}
