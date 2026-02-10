// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct TagChip: View {
    let tag: ItemTagData

    @Environment(\.colorScheme)
    private var colorScheme
    
    public init(tag: ItemTagData) {
        self.tag = tag
    }

    public var body: some View {
        HStack {
            Circle()
                .fill(Color(UIColor(tag.color)))
                .frame(width: ItemTagColorMetrics.regular.size, height: ItemTagColorMetrics.regular.size)
            
            Text(tag.name)
        }
        .font(.body)
        .foregroundStyle(.base1000)
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(colorScheme == .dark ? .neutral200 : .base0)
        )
    }
}
    
#Preview {
    TagChip(tag: .init(tagID: ItemTagID(), vaultID: VaultID(), name: "Name", color: .indigo, position: 0, modificationDate: Date()))
}
