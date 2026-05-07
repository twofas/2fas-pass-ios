// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

/// Standard trailing-aligned ellipsis trigger used as the `label` of `Menu`s in row cells.
/// Reads `\.isEnabled` so applying `.disabled(...)` on the parent `Menu` automatically
/// dims the trigger.
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
