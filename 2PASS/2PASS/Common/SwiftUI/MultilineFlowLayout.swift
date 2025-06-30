// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct MultilineFlowLayout: Layout {
    
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var totalHeight: CGFloat = 0
        var currentWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentWidth + size.width > maxWidth { // Move to new row
                totalHeight += rowHeight + lineSpacing
                currentWidth = 0
                rowHeight = 0
            }

            rowHeight = max(rowHeight, size.height)
            currentWidth += size.width + spacing
        }

        totalHeight += rowHeight // Add last row height
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (_, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth { // Move to new row
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
