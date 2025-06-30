// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct TransferItemsFileSummaryView: View {
    
    @State var presenter: TransferItemsFileSummaryPresenter
    
    var body: some View {
        SettingsDetailsForm(Text(T.transferInstructionsHeader(presenter.service.name).localizedKey)) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(presenter.passwords.count, format: .number)
                        .font(.bodyEmphasized)
                        .foregroundStyle(.neutral950)
                    
                    Text(T.transferFileSummaryCounterDescription.localizedKey)
                        .font(.footnote)
                        .foregroundStyle(.neutral600)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(.success500)
            }
            .listRowInsets(EdgeInsets(top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l))
            
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
    TransferItemsFileSummaryView(presenter: .init(service: .bitWarden, passwords: [], onClose: {}))
}
