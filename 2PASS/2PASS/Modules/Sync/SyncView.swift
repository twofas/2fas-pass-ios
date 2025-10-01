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
        SettingsDetailsForm(T.settingsEntryCloudSync.localizedKey) {
            Section {
                Toggle(T.settingsCloudSyncIcloudLabel.localizedKey, isOn: $presenter.icloudSyncEnabled)
                
                Button {
                    presenter.onWebDAV()
                } label: {
                    SettingsRowView(title: T.settingsCloudSyncWebdavLabel.localizedKey, additionalInfo: Text(presenter.webDAVEnableStatus))
                }
            } footer: {
                VStack(alignment: .leading) {
                    if let status = presenter.status {
                        Text(T.settingsCloudSyncStatus(status).localizedKey)
                    }
                    
                    if let date = presenter.lastSyncDate {
                        Text(T.settingsCloudSyncLastSync(date.formatted(date: .numeric, time: .standard)).localizedKey)
                    }
                }
                .settingsFooter()
            }
            
            if presenter.showUpgradePlanButton {
                Section {
                    Button(T.paywallNoticeCta.localizedKey) {
                        presenter.onUpgradePlan()
                    }
                }
                .listSectionSpacing(0)
            }
            
            if presenter.showUpdateAppButton {
                Section {
                    Button(T.cloudSyncInvalidSchemaErrorCta.localizedKey) {
                        presenter.onUpdateApp()
                    }
                }
                .listSectionSpacing(0)
            }
            
        } header: {
            SettingsHeaderView(
                icon: .sync,
                title: Text(T.settingsCloudSyncTitle.localizedKey),
                description: Text(T.settingsCloudSyncDescription.localizedKey)
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
