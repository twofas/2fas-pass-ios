// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import SwiftUIIntrospect

struct SettingsTextFieldView: View {

    let title: Text
    let footer: Text?
    @Binding var text: String
    let onSave: () -> Void

    init(title: Text, footer: Text? = nil, text: Binding<String>, onSave: @escaping () -> Void) {
        self.title = title
        self.footer = footer
        self._text = text
        self.onSave = onSave
    }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        SettingsDetailsForm(title) {
            Section {
                TextField(text: $text) {
                    title
                }
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { dismiss() }
                .autocorrectionDisabled()
                .introspect(.textField, on: .iOS(.v17, .v18, .v26)) { textField in
                    textField.clearButtonMode = .always
                }
            } footer: {
                footer?.settingsFooter()
            }
        }
        .onAppear {
            isFocused = true
        }
        .onDisappear {
            onSave()
        }
    }
}
