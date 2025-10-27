// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct PasswordsCellViewPreview: UIViewRepresentable {
    
    func makeUIView(context: Context) -> PasswordsCellView {
        let view = PasswordsCellView()
        view.update(cellData: PasswordCellData(itemID: ItemID(), name: "Name", username: "Username", iconType: .label(labelTitle: "EA", labelColor: .red), hasUsername: true, hasPassword: true, uris: [], normalizeURI: { URL(string: $0) }))
        return view
    }
    
    func updateUIView(_ uiView: PasswordsCellView, context: Context) {}
}

#Preview {
    PasswordsCellViewPreview()
        .frame(height: 82)
}
