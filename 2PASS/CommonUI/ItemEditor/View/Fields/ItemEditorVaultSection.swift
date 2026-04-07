// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemEditorVaultSection: View {

    @Bindable
    var presenter: _ItemEditorFormPresenter
    let resignFirstResponder: Callback

    var body: some View {
        Section {
            HStack(spacing: Spacing.s) {
                Text(.itemEditorVaultLabel)
                    .foregroundStyle(.mainText)

                Spacer()

                Picker("", selection: $presenter.selectedVaultID) {
                    ForEach(presenter.availableVaults) { vault in
                        Text(vault.name)
                            .tag(vault.vaultID)
                    }
                }
            }
            .formFieldChanged(presenter.vaultChanged)
        }
        .listSectionSpacing(Spacing.l)
    }
}
