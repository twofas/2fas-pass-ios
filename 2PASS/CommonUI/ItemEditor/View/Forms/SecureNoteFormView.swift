// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let minHeightNotes: CGFloat = 80
}

struct SecureNoteFormView: View {
    
    enum Field: Hashable {
        case notes
    }
    
    @Bindable
    var presenter: SecureNoteEditorFormPresenter
    let resignFirstResponder: Callback

    @State
    private var fieldWidth: CGFloat?
    
    @FocusState
    private var focusField: Field?
    
    var body: some View {
        HStack {
            Spacer()
            ItemEditorIconView(content: .contentType(.secureNote))
            Spacer()
        }
        .listRowBackground(Color.clear)
        
        Section {
            LabeledInput(label: T.loginNameLabel.localizedKey, fieldWidth: $fieldWidth) {
                TextField(T.loginNameLabel.localizedKey, text: $presenter.name)
            }
            .formFieldChanged(presenter.nameChanged)
        }
        .font(.body)
        .listSectionSpacing(Spacing.m)
        
        Section {
            if presenter.isReveal {
                TextField("", text: $presenter.text, axis: .vertical)
                    .focused($focusField, equals: .notes)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.sentences)
                    .multilineTextAlignment(.leading)
                    .limitText($presenter.text, to: Config.maxSecureNotesLength)
                    .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .formFieldChanged(presenter.textChanged)
                    .onTapGesture {
                        focusField = .notes
                    }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.neutral200)
                    
                    Button("Tap to edit") {
                        withAnimation {
                            presenter.isReveal = true
                            focusField = .notes
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.bottom, Spacing.xs)
                }
                .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .center)
            }

        } header: {
            Text("Secure Note")
        }
        .listSectionSpacing(Spacing.l)
        
        ItemEditorProtectionLevelSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
        
        ItemEditorTagsSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
    }
}
