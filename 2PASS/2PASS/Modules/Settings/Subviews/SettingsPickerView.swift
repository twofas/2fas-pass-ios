// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct SettingsPicker<Value> where Value: Hashable {
    let options: [Value]
    let selected: Binding<Value?>
    let formatter: (Value) -> String
    
    init(options: [Value], selected: Binding<Value?>, formatter: @escaping (Value) -> String) {
        self.options = options
        self.selected = selected
        self.formatter = formatter
    }
}

extension SettingsPicker where Value == String {
    
    init(options: [String], selected: Binding<String?>) {
        self.options = options
        self.selected = selected
        self.formatter = { $0 }
    }
}

struct SettingsPickerView<SelectionValue>: View where SelectionValue: Hashable {
    
    let title: Text
    let footer: Text?
    let options: [SelectionValue]
    @Binding private var selected: SelectionValue?
    let formatter: (SelectionValue) -> String
    
    init(title: Text, options: [SelectionValue], selected: Binding<SelectionValue?>, footer: Text? = nil, formatter: @escaping (SelectionValue) -> String) {
        self.title = title
        self.options = options
        self._selected = selected
        self.formatter = formatter
        self.footer = footer
    }
    
    var body: some View {
        SettingsDetailsForm(title) {
            Section {
                Picker(selection: $selected) {
                    ForEach(options, id: \.self) { option in
                        Text(formatter(option))
                            .tag(option)
                    }
                } label: {}
                .pickerStyle(.inline)
            } footer: {
                footer?.settingsFooter()
            }
        }
    }
}

extension SettingsPickerView {
    
    init(title: Text, footer: Text? = nil, picker: SettingsPicker<SelectionValue>) {
        self.init(title: title, options: picker.options, selected: picker.selected, footer: footer, formatter: picker.formatter)
    }
}

import Data

#Preview {
    @Previewable @State var selected: AppLockAttempts? = .try10
    
    SettingsPickerView(title: Text("Title"), options: AppLockAttempts.allCases, selected: $selected, formatter: { $0.rawValue })
}
