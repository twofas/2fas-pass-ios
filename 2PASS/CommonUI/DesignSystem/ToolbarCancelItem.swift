// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

/// Cancellation-action toolbar item wrapping a `ToolbarCancelButton`.
///
/// Adapts per OS via the underlying `ToolbarCancelButton`:
/// - iOS 26+ → leading X icon (Liquid Glass)
/// - earlier → localized "Cancel" text button
///
/// ```
/// ToolbarCancelItem {
///     dismiss()
/// }
/// ```
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
