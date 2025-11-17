// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemEditorProtectionLevelSection: View {
    
    let presenter: ItemEditorFormPresenter
    let resignFirstResponder: Callback
    
    var body: some View {
        Section {
            Button {
                resignFirstResponder()
                presenter.onChangeProtectionLevel()
            } label: {
                HStack(spacing: Spacing.s) {
                    Text(T.loginSecurityLevelLabel.localizedKey)
                        .foregroundStyle(Asset.mainTextColor.swiftUIColor)

                    Spacer()
                    
                    Label {
                        Text(presenter.protectionLevel.title.localizedKey)
                    } icon: {
                        presenter.protectionLevel.icon
                            .renderingMode(.template)
                            .foregroundStyle(.accent)
                    }
                    .labelStyle(.rowValue)
                    .foregroundStyle(.neutral500)
                    
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(Asset.inactiveColor.swiftUIColor)
                }
                .contentShape(Rectangle())
            }
            .formFieldChanged(presenter.protectionLevelChanged)
            .buttonStyle(.plain)
        } header: {
            Text(T.loginSecurityLevelHeader.localizedKey)
        }
        .listSectionSpacing(Spacing.l)
    }
}
