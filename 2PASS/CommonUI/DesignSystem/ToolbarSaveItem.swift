// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

/// Confirmation-action toolbar item with a save action.
///
/// Renders one of three states:
/// - loading → `ProgressView` (no button)
/// - iOS 26+ → `Button(role: .confirm)` with the system-provided label
/// - earlier → labeled "Save" button
///
/// ```
/// ToolbarSaveItem {
///     presenter.onSave()
/// }
/// .loading(presenter.isTesting)
/// .disabled(!presenter.canSave)
/// ```
public struct ToolbarSaveItem: ToolbarContent {

    private let action: () -> Void

    private var isLoading = false
    private var isDisabled = false

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            saveControl
        }
    }

    @ViewBuilder
    private var saveControl: some View {
        if isLoading {
            ProgressView()
        } else if #available(iOS 26, *) {
            Button(role: .confirm, action: action)
                .disabled(isDisabled)
        } else {
            Button(action: action) {
                Text(.commonSave)
            }
            .disabled(isDisabled)
        }
    }

    public func loading(_ loading: Bool = true) -> Self {
        var instance = self
        instance.isLoading = loading
        return instance
    }

    public func disabled(_ disabled: Bool) -> Self {
        var instance = self
        instance.isDisabled = disabled
        return instance
    }
}
