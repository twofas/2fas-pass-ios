// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

struct BackupImportSummaryView: View {

    @State var presenter: BackupImportSummaryPresenter

    private let iconWidth = 20.0

    var body: some View {
        Group {
            switch presenter.state {
            case .loading:
                ProgressView(label: {
                    Text(.backupImportingFileText)
                })
                .progressViewStyle(.circular)
                .tint(nil)
                .controlSize(.large)

            case .ready(let summary, let contentTypes, let tagsCount):
                readyContent(summary: summary, contentTypes: contentTypes, tagsCount: tagsCount)

            case .failure:
                BackupImportFailureView(onClose: presenter.onClose)
            }
        }
        .task {
            await presenter.onAppear()
        }
        .router(router: BackupImportSummaryRouter(), destination: $presenter.destination)
    }

    private func readyContent(
        summary: [ItemContentType: Int],
        contentTypes: [ItemContentType],
        tagsCount: Int
    ) -> some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.backupImportSummaryTitle) {
                ForEach(contentTypes, id: \.self) { contentType in
                    summarySection(
                        count: summary[contentType] ?? 0,
                        icon: contentType.iconSystemName.map { Image(systemName: $0) },
                        description: descriptionForContentType(contentType)
                    )
                }

                if tagsCount > 0 {
                    summarySection(
                        count: tagsCount,
                        icon: Image(systemName: "tag"),
                        description: .transferFileSummaryTagsCounterDescription
                    )
                }
            } header: {
                SettingsHeaderView(
                    icon: {
                        SettingsIconView(icon: .transferItems)
                            .iconColor(.black)
                    },
                    title: {
                        Text(.backupImportSummaryTitle)
                    },
                    description: {
                        Text(.backupImportSummaryDescription)
                            .foregroundStyle(.neutral600)
                    }
                )
                .settingsIconStyle(.border)
            }
            .listSectionSpacing(Spacing.m)

            VStack(spacing: Spacing.l) {
                if presenter.hasMultipleVaults {
                    vaultPicker
                }

                Button(.backupImportSummaryCta) {
                    presenter.onProceed()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
            .padding(.top, Spacing.m)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private var vaultPicker: some View {
        GroupedSection {
            HStack {
                Text(.backupImportSummaryVaultPickerLabel)

                Spacer()

                Picker(selection: $presenter.selectedVaultID) {
                    ForEach(presenter.availableVaults, id: \.vaultID) { vault in
                        Text(vault.name).tag(vault.vaultID)
                    }
                } label: {
                    EmptyView()
                }
            }
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
        case .wifi:
            .transferFileSummaryWifiCounterDescription
        case .unknown:
            .transferFileSummaryOthersCounterDescription
        }
    }
}
