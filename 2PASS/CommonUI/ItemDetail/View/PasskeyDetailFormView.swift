// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct PasskeyDetailFormView: View {

    enum SelectedField: Hashable {
        case username
    }

    let presenter: PasskeyDetailFormPresenter

    @State
    private var selectedField: SelectedField?

    private var isTextToInsertMode: Bool {
        if #available(iOS 18.0, *) {
            presenter.autoFillEnvironment?.isTextToInsert == true
        } else {
            false
        }
    }

    var body: some View {
        GroupedSection {
            ItemDetailFormTitle(
                name: presenter.name,
                icon: .contentType(.passkey)
            )

            ItemDetailFormActionsRow(
                key: .passkeyWebsiteLabel,
                value: { Text(presenter.rpID) },
                actions: {[
                    UIAction(title: String(localized: .passkeyViewActionCopyWebsite)) { _ in
                        presenter.onCopyRpID()
                    }
                ]}
            )

            ItemDetailFormActionsRow(
                key: .loginUsernameLabel,
                value: { Text(presenter.username) },
                actions: {[
                    UIAction(title: String(localized: .loginViewActionCopyUsername)) { _ in
                        presenter.onCopyUsername()
                    }
                ]}
            )
            .showValueAsButton(isTextToInsertMode)
            .selected($selectedField, equals: .username)
            .onChange(of: selectedField == .username) { _, newValue in
                if newValue {
                    presenter.onSelectUsername()
                }
            }

            ItemDetailFormProtectionLevel(presenter.protectionLevel)
        }
        .onAppear {
            selectedField = nil
        }
    }
}
