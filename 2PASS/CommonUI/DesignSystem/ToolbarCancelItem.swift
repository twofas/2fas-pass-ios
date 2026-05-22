// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

/// Cancellation-action toolbar item wrapping `ToolbarCancelButton` (X icon on iOS 26+,
/// localized "Cancel" text earlier).
public struct ToolbarCancelItem: ToolbarContent {

    private let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            ToolbarCancelButton(action: action)
        }
    }
}
