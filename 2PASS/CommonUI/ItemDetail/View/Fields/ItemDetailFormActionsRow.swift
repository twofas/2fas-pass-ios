// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemDetailFormActionsRow<Value>: View where Value: View {
    
    let key: LocalizedStringResource
    let value: Value
    let actions: [UIAction]

    private var lineLimit: Int?
    private var onSelect: (() -> Void)?
    
    @State
    private var isSelected = false
    
    init(key: LocalizedStringResource, @ViewBuilder value: () -> Value, actions: () -> [UIAction]) {
        self.key = key
        self.actions = actions()
        self.value = value()
    }
    
    var body: some View {
        Button {
            isSelected = true
            onSelect?()
        } label: {
            content
        }
        .buttonStyle(.twofasPlain)
        .itemDetailFormRowBackground(isSelected ? Color.neutral100 : nil)
        .editMenu($isSelected, actions: actions)
    }
    
    func selected<SelectedValue>(_ binding: Binding<SelectedValue>, equals: SelectedValue) -> some View where SelectedValue: Hashable {
        onSelect {
            binding.wrappedValue = equals
        }
        .onChange(of: binding.wrappedValue) { _, newValue in
            isSelected = (newValue == equals)
        }
    }
    
    func lineLimit(_ limit: Int?) -> Self {
        var instance = self
        instance.lineLimit = limit
        return instance
    }
    
    private var content: some View {
        LabeledContent {
            value
        } label: {
            Text(key)
        }
        .contentShape(Rectangle())
        .labeledContentStyle(.listCell(lineLimit: lineLimit))
    }
    
    private func onSelect(_ action: @escaping Callback) -> Self {
        var instance = self
        instance.onSelect = action
        return instance
    }
}
