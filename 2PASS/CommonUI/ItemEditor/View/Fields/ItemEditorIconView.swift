// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let iconSize: CGFloat = 60
}

struct ItemEditorIconView: View {
    
    let content: IconContent
    
    var body: some View {
        IconRendererView(content: content)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
    }
}
