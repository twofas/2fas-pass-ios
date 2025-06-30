// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct BackButton: View {
    let backAction: Callback
    var body: some View {
        Button {
            backAction()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.title2)
                .tint(Asset.accentColor.swiftUIColor)
        }
        .accessibilityLabel(Text(verbatim: "Back button"))
    }
}
