// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct WrappingHStack<Item: Identifiable & Hashable, Content: View>: View {
    let width: CGFloat
    let spacing: CGFloat
    let items: [Item]

    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        wrappingHStack()
    }

    func wrappingHStack() -> some View {
        var itemXPosition: CGFloat = 0
        var itemYPosition: CGFloat = 0

        return HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                ForEach(items, id: \.id) { item in
                    content(item)
                        .padding(.vertical, 4)
                        .alignmentGuide(.leading, computeValue: { dimension in
                            if abs(itemXPosition - dimension.width) > width {
                                itemXPosition = 0
                                itemYPosition -= dimension.height
                            }
                            let result = itemXPosition
                            if item == self.items.last! {
                                itemXPosition = 0
                            } else {
                                itemXPosition -= dimension.width + spacing
                            }
                            return result
                        })
                        .alignmentGuide(.top, computeValue: { _ in
                            let result = itemYPosition
                            if item == self.items.last! {
                                itemYPosition = 0
                            }
                            return result
                        })
                }
            }
            Spacer(minLength: 0)
        }
    }
}

