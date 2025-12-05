// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct TagChip: View {
    let tag: ItemTagData

    public init(tag: ItemTagData) {
        self.tag = tag
    }

    public var body: some View {
        Text(tag.name)
            .font(.body)
            .foregroundStyle(.base1000)
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.neutral200)
            )
    }
}
    
