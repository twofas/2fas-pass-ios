// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct TagContentCell: View {

    let name: Text
    let color: ItemTagColor?
    let subtitle: Text?

    public init(name: Text, color: ItemTagColor?, subtitle: Text? = nil) {
        self.name = name
        self.color = color
        self.subtitle = subtitle
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            if let color {
                Circle()
                    .fill(Color(UIColor(color)))
                    .frame(width: ItemTagColorMetrics.regular.size, height: ItemTagColorMetrics.regular.size)
            }

            VStack(alignment: .leading, spacing: 0) {
                name
                    .foregroundStyle(.primary)
                    .font(.bodyEmphasized)

                subtitle
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                    .font(.footnote)
            }
        }
    }
}
