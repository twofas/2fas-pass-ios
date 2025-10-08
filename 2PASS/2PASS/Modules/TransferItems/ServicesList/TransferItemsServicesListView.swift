// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct TransferItemsServicesListView: View {
    
    @State var presenter: TransferItemsServicesListPresenter
    
    var body: some View {
        SettingsDetailsForm(Text(T.settingsEntryTransferFromOtherApps.localizedKey)) {
            Section {
                ForEach(ExternalService.allCases.sorted(by: { $0.name < $1.name }), id: \.self) { service in
                    Button {
                        presenter.onSelect(service)
                    } label: {
                        SettingsRowView(icon: service.settingsIcon, title: Text(service.name), actionIcon: .chevron)
                            .settingsIconStyle(.border)
                    }
                }
            } header: {
                Text(T.transferServicesListHeader.localizedKey)
            } footer: {
                Text(T.transferServicesListFooter.localizedKey)
                    .settingsFooter()
            }
        }
        .toolbar {
            if presenter.flowContext.kind == .quickSetup {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.flowContext.onClose?()
                    }
                }
            }
        }
        .router(router: TransferItemsServicesListRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        TransferItemsServicesListView(presenter: .init(
            interactor: ModuleInteractorFactory.shared.transferItemsServicesListInteractor(),
            flowContext: .settings
        ))
    }
}
