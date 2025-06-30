// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct EmptySearchView: View {
    var body: some View {
        Group {
            Text(Image(systemName: "exclamationmark.magnifyingglass")) + Text(" ") + Text(T.loginSearchNoResultsTitle.localizedKey)
        }
        .font(.subheadline)
        .foregroundStyle(Asset.inactiveColor.swiftUIColor)
    }
}

#Preview {
    EmptySearchView()
}
