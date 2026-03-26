// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct PasskeyEditorFormView: View {

    @Bindable
    var presenter: PasskeyEditorFormPresenter
    let resignFirstResponder: Callback

    @State
    private var fieldWidth: CGFloat?

    var body: some View {
        HStack {
            Spacer()
            ItemEditorIconView(content: .contentType(.passkey))
            Spacer()
        }
        .listRowBackground(Color.clear)

        Section {
            LabeledInput(label: String(localized: .passkeyNameLabel), fieldWidth: $fieldWidth) {
                TextField(String(localized: .passkeyNameLabel), text: $presenter.name)
            }
            .formFieldChanged(presenter.nameChanged)
        }
        .font(.body)
        .listSectionSpacing(Spacing.m)

        Section {
            LabeledContent {
                Text(presenter.rpID)
            } label: {
                Text(.passkeyWebsiteLabel)
            }

            LabeledContent {
                Text(presenter.username)
            } label: {
                Text(.loginUsernameLabel)
            }
        }
        .font(.body)
        .listSectionSpacing(Spacing.m)

        ItemEditorProtectionLevelSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
        ItemEditorTagsSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
    }
}
