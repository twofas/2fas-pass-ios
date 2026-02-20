// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct ItemDetailFormTitle: View {
    
    let name: String
    let description: String?
    let icon: IconContent?
    
    init(name: String, description: String? = nil, icon: IconContent?) {
        self.name = name
        self.description = description
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            IconRendererView(content: icon)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(name, format: .itemName)
                    .font(.title3Emphasized)
                    .foregroundStyle(.neutral950)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let description {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.neutral950)
                }
            }
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .padding([.vertical], Spacing.xs)
    }
}
