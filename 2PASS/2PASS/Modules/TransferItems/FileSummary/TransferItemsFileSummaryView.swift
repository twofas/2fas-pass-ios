// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Data

struct TransferItemsFileSummaryView: View {
    
    @State var presenter: TransferItemsFileSummaryPresenter
    
    var body: some View {
        SettingsDetailsForm(Text(T.transferInstructionsHeader(presenter.service.name).localizedKey)) {
            ForEach(presenter.contentTypes, id: \.self) { contentType in
                Section {
                    HStack(spacing: Spacing.s) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            let count = Text(presenter.summary[contentType] ?? 0, format: .number)
                                .font(.bodyEmphasized)
                                .foregroundStyle(.neutral950)
                                                        
                            if let icon = contentType.iconSystemName {
                                HStack(spacing: Spacing.s) {
                                    Image(systemName: icon)
                                    count
                                }
                            } else {
                                count
                            }
                            
                            Text(T.transferFileSummaryCounterDescription.localizedKey)
                                .font(.footnote)
                                .foregroundStyle(.neutral600)
                        }
                        
                        Spacer()
                    }
                }
                .listRowInsets(EdgeInsets(top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l))
            }
            
        } header: {
            SettingsHeaderView(
                icon: {
                    SettingsIconView(icon: presenter.service.settingsIcon)
                },
                title: {
                    HStack(spacing: Spacing.s) {
                        Text(presenter.service.name)
                        Image(.transferIcon)
                        Text(T.appName.localizedKey)
                    }
                },
                description: {
                    Text(T.transferFileSummaryDescription.localizedKey)
                        .foregroundStyle(.neutral600)
                }
            )
            .settingsIconStyle(.border)
        }
        .listSectionSpacing(Spacing.m)
        
        Button(T.transferFileSummaryCta.localizedKey) {
            presenter.onProceed()
        }
        .buttonStyle(.filled)
        .controlSize(.large)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .background(Color(UIColor.systemGroupedBackground))
        .router(router: TransferItemsFileSummaryRouter(), destination: $presenter.destination)
    }
}

#Preview {
    TransferItemsFileSummaryView(presenter: .init(service: .bitWarden, result: ExternalServiceImportResult(items: [
        .login(.init(id: .init(), vaultId: .init(), metadata: .init(creationDate: Date(), modificationDate: Date(), protectionLevel: .confirm, trashedStatus: .no, tagIds: nil), name: nil, content: .init(name: nil, username: nil, password: nil, notes: nil, iconType: .domainIcon(nil), uris: nil)))
    ]), onClose: {}))
}
