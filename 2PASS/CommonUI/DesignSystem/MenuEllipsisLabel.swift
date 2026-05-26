// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct MenuEllipsisLabel: View {

    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public var body: some View {
        Image(systemName: "ellipsis")
            .foregroundStyle(.neutral500)
            .frame(width: 40, height: 40, alignment: .trailing)
            .opacity(isEnabled ? 1.0 : 0.4)
    }
}
