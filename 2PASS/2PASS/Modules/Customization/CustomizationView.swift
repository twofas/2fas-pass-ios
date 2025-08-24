// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct CustomizationView: View {
    
    @State
    var presenter: CustomizationPresenter
    
    var body: some View {
        SettingsDetailsForm(T.settingsEntryCustomization.localizedKey) {
            Section {
                Button {
                    presenter.onChangeDefaultAction()
                } label: {
                    LabeledContent(T.settingsEntryLoginClickAction.localizedKey, value: presenter.selectedDefaultActionDesctiption)
                        .labeledContentStyle(.navigationSettings)
                }
            } footer: {
                Text(T.settingsEntryLoginClickActionDescription.localizedKey)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onManageTags()
                } label: {
                    SettingsRowView(title: T.settingsEntryManageTags.localizedKey)
                }
            } footer: {
                Text(T.settingsEntryManageTagsDescription.localizedKey)
                    .settingsFooter()
            }
        }
        .router(router: CustomizationRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        CustomizationRouter.buildView()
    }
}
