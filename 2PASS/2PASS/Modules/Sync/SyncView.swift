// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct SyncView: View {
    
    @State
    var presenter: SyncPresenter
    
    var body: some View {
        SettingsDetailsForm(.settingsEntryCloudSync) {
            Section {
                Toggle(.settingsCloudSyncIcloudLabel, isOn: $presenter.icloudSyncEnabled)
                    .tint(.accentColor)
                
                Button {
                    presenter.onWebDAV()
                } label: {
                    SettingsRowView(title: .settingsCloudSyncWebdavLabel, additionalInfo: Text(presenter.webDAVEnableStatus))
                }
            } footer: {
                VStack(alignment: .leading) {
                    if let status = presenter.status {
                        Text(.settingsCloudSyncStatus(status))
                    }
                    
                    if let date = presenter.lastSyncDate {
                        Text(.settingsCloudSyncLastSync(date.formatted(date: .numeric, time: .standard)))
                    }
                }
                .settingsFooter()
            }
            
            if presenter.showUpgradePlanButton {
                Section {
                    Button(.paywallNoticeCta) {
                        presenter.onUpgradePlan()
                    }
                }
                .listSectionSpacing(0)
            }
            
            if presenter.showUpdateAppButton {
                Section {
                    Button(.cloudSyncInvalidSchemaErrorCta) {
                        presenter.onUpdateApp()
                    }
                }
                .listSectionSpacing(0)
            }
            
        } header: {
            SettingsHeaderView(
                icon: .sync,
                title: Text(.settingsCloudSyncTitle),
                description: Text(.settingsCloudSyncDescription)
            )
        }
        .onAppear {
            presenter.onAppear()
        }
        .router(router: SyncRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        SyncRouter.buildView()
    }
}
