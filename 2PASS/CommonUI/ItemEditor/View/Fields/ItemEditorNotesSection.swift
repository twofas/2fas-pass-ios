// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let notesMinHeight: CGFloat = 80
}

struct ItemEditorNotesSection<Field: Hashable>: View {

    @Binding
    private var notes: String
    private let notesChanged: Bool
    private let focusField: FocusState<Field?>.Binding
    private let focusedField: Field
    private let header: LocalizedStringResource

    init(
        notes: Binding<String>,
        notesChanged: Bool,
        focusField: FocusState<Field?>.Binding,
        focusedField: Field,
        header: LocalizedStringResource
    ) {
        self._notes = notes
        self.notesChanged = notesChanged
        self.focusField = focusField
        self.focusedField = focusedField
        self.header = header
    }

    var body: some View {
        Section {
            notesTextField
                .frame(maxWidth: .infinity, minHeight: Constants.notesMinHeight, alignment: .topLeading)
                .contentShape(Rectangle())
                .formFieldChanged(notesChanged)
        } header: {
            Text(header)
        }
        .onTapGesture {
            focusField.wrappedValue = focusedField
        }
        .listSectionSpacing(Spacing.l)
    }

    private var notesTextField: some View {
        TextField("", text: $notes, axis: .vertical)
            .focused(focusField, equals: focusedField)
            .autocorrectionDisabled(false)
            .textInputAutocapitalization(.sentences)
            .multilineTextAlignment(.leading)
            .limitText($notes, to: Config.maxNotesLength)
    }
}
