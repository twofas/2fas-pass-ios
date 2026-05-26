// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct ToolbarSaveItem: ToolbarContent {

    private let action: () -> Void

    private var isLoading = false
    private var isDisabled = false
    private var customLabel: Text?

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            saveControl
        }
    }

    private var resolvedLabel: Text {
        customLabel ?? Text(.commonSave)
    }

    @ViewBuilder
    private var saveControl: some View {
        if isLoading {
            ProgressView()
                .tint(nil)
        } else if #available(iOS 26, *) {
            if let customLabel {
                Button(role: .confirm, action: action) { customLabel }
                    .disabled(isDisabled)
            } else {
                Button(role: .confirm, action: action)
                    .disabled(isDisabled)
            }
        } else {
            Button(action: action) { resolvedLabel }
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

    public func label(_ label: Text) -> Self {
        var instance = self
        instance.customLabel = label
        return instance
    }
}

extension ToolbarSaveItem {

    public func label(_ label: LocalizedStringResource) -> Self {
        self.label(Text(label))
    }
}
