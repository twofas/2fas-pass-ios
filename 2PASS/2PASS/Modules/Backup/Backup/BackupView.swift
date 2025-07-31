// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupView: View {
    
    @State
    var presenter: BackupPresenter
    
    var body: some View {
        SettingsDetailsForm(Text(T.settingsEntryImportExport.localizedKey)) {
            Section {
                Button(T.backupImportCta.localizedKey) {
                    presenter.onImport()
                }
            } header: {
                Text(T.backupImportHeader.localizedKey)
                    .padding(.top, Spacing.l)
            } footer: {
                Text(T.backupImportFooter.localizedKey)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onExport()
                } label: {
                    SettingsRowView(
                        title: T.backupExportCta.localizedKey,
                        actionIcon: .chevron
                    )
                }
                .disabled(presenter.isExportDisabled)
                
            } header: {
                Text(T.backupExportHeader)
            } footer: {
                Text(T.backupExportFooter)
                    .settingsFooter()
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .toolbar {
            if presenter.flowContext.kind == .quickSetup {
                ToolbarItem(placement: .cancellationAction) {
                    Button(T.commonCancel.localizedKey) {
                        presenter.flowContext.onClose?()
                    }
                }
            }
        }
        .router(router: BackupRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        BackupView(presenter: .init(flowContext: .settings, interactor: ModuleInteractorFactory.shared.backupModuleInteractor()))
    }
}
