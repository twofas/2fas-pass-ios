// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

struct TransferItemsFileSummaryView: View {

    @State var presenter: TransferItemsFileSummaryPresenter

    let iconWidth = 20.0

    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.transferInstructionsHeader(presenter.service.name)) {
                ForEach(presenter.contentTypes, id: \.self) { contentType in
                    summarySection(
                        count: presenter.summary[contentType] ?? 0,
                        icon: contentType.iconSystemName.map { Image(systemName: $0) },
                        description: descriptionForContentType(contentType)
                    )
                }

                if presenter.itemsConvertedToSecureNotes > 0 {
                    summarySection(
                        count: presenter.itemsConvertedToSecureNotes,
                        icon: Image(systemName: "questionmark.circle"),
                        description: .transferFileSummaryOthersCounterDescription
                    )
                }
                
                if presenter.tagsCount > 0 {
                    summarySection(
                        count: presenter.tagsCount,
                        icon: Image(systemName: "tag"),
                        description: .transferFileSummaryTagsCounterDescription
                    )
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
                            Text(.appName)
                        }
                    },
                    description: {
                        Text(.transferFileSummaryDescription)
                            .foregroundStyle(.neutral600)
                    }
                )
                .settingsIconStyle(.border)
            }
            .listSectionSpacing(Spacing.m)
            
            Button(.transferFileSummaryCta) {
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

    @ViewBuilder
    private func summarySection(count: Int, icon: Image?, description: LocalizedStringResource) -> some View {
        Section {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    let countText = Text(count, format: .number)
                        .font(.bodyEmphasized)
                        .foregroundStyle(.neutral950)

                    if let icon {
                        HStack(spacing: Spacing.xs) {
                            icon.frame(width: iconWidth)
                            countText
                        }
                    } else {
                        countText
                    }

                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.neutral600)
                }

                Spacer()
            }
        }
        .listRowInsets(EdgeInsets(top: Spacing.l, leading: Spacing.l, bottom: Spacing.l, trailing: Spacing.l))
    }

    private func descriptionForContentType(_ contentType: ItemContentType) -> LocalizedStringResource {
        switch contentType {
        case .login:
            .transferFileSummaryLoginsCounterDescription
        case .secureNote:
            .transferFileSummarySecureNotesCounterDescription
        case .paymentCard:
            .transferFileSummaryPaymentCardsCounterDescription
        case .unknown:
            .transferFileSummaryOthersCounterDescription
        }
    }
}

#Preview {
    TransferItemsFileSummaryView(presenter: .init(service: .bitWarden, result: ExternalServiceImportResult(
        items: [
            .login(.init(id: .init(), vaultId: .init(), metadata: .init(creationDate: Date(), modificationDate: Date(), protectionLevel: .confirm, trashedStatus: .no, tagIds: nil), name: nil, content: .init(name: nil, username: nil, password: nil, notes: nil, iconType: .domainIcon(nil), uris: nil))),
        ],
        itemsConvertedToSecureNotes: 12), onClose: {}
    ))
}
