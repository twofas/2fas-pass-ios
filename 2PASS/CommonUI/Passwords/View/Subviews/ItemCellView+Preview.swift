// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemCellViewPreview: UIViewRepresentable {

    func makeUIView(context: Context) -> ItemCellView {
        let view = ItemCellView()
        view.update(with: .init(
            itemID: ItemID(),
            name: "Name",
            description: "Description",
            iconType: .contentType(.secureNote),
            tagColors: [],
            actions: []
        ))
        return view
    }

    func updateUIView(_ uiView: ItemCellView, context: Context) {}
}

#Preview {
    ItemCellViewPreview()
        .frame(height: 68)
}
