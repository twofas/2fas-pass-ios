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
        SettingsDetailsForm(.settingsEntryCustomization) {
            Section {
                Button {
                    presenter.onEditDeviceName()
                } label: {
                    LabeledContent(String(localized: .settingsEntryDeviceNickname), value: presenter.deviceName)
                        .labeledContentStyle(.navigationSettings)
                }
            } footer: {
                Text(.settingsEntryDeviceNicknameDescription)
                    .settingsFooter()
            }

            Section {
                Button {
                    presenter.onChangeDefaultAction()
                } label: {
                    LabeledContent(String(localized: .settingsEntryLoginClickAction), value: presenter.selectedDefaultActionDesctiption)
                        .labeledContentStyle(.navigationSettings)
                }
            } footer: {
                Text(.settingsEntryLoginClickActionDescription)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onManageTags()
                } label: {
                    SettingsRowView(title: .settingsEntryManageTags)
                }
            } footer: {
                Text(.settingsEntryManageTagsDescription)
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
