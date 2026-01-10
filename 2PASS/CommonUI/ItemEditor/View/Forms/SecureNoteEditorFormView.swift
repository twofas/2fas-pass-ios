// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let minHeightNotes: CGFloat = 80
    static let minHeightAdditionalInfo: CGFloat = 80
}

struct SecureNoteEditorFormView: View {
    
    enum Field: Hashable {
        case notes
        case additionalInfo
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
            LabeledInput(label: String(localized: .secureNoteNameLabel), fieldWidth: $fieldWidth) {
                TextField(String(localized: .loginNameLabel), text: $presenter.name)
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
                LockButton(text: Text(.secureNoteTextRevealEditAction)) {
                    withAnimation {
                        presenter.isReveal = true
                        focusField = .notes
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Constants.minHeightNotes, alignment: .center)
            }

        } header: {
            Text(.secureNoteTextLabel)
        }
        .listSectionSpacing(Spacing.l)
        .sensoryFeedback(.selection, trigger: presenter.isReveal) { _, newValue in
            newValue
        }
        
        ItemEditorProtectionLevelSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
        
        ItemEditorTagsSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
        
        if presenter.additionalInfo != nil {
            Section {
                TextField("", text: additionalInfoBinding, axis: .vertical)
                    .focused($focusField, equals: .additionalInfo)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.sentences)
                    .multilineTextAlignment(.leading)
                    .limitText(additionalInfoBinding, to: Config.maxSecureNotesAdditionalInfoLength)
                    .frame(maxWidth: .infinity, minHeight: Constants.minHeightAdditionalInfo, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .formFieldChanged(presenter.additionalInfoChanged)
                    .onTapGesture {
                        focusField = .additionalInfo
                    }
            } header: {
                Text(.secureNoteAdditionalInfoLabel)
            }
        }
    }
    
    private var additionalInfoBinding: Binding<String> {
        Binding {
            presenter.additionalInfo ?? ""
        } set: {
            presenter.additionalInfo = $0
        }

    }
}
