// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Common
import CommonUI
import Data
import SwiftUI

@available(iOS 26.0, *)
struct CredentialExchangeImportView: View {

    @State var presenter: CredentialExchangeImportPresenter

    var body: some View {
        Group {
            switch presenter.viewState {
            case .loading:
                ProgressView()
            case .summary:
                summaryContent
            case .error:
                errorContent
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    presenter.onClose()
                }
            }
        }
        .router(router: CredentialExchangeImportRouter(), destination: $presenter.destination)
        .task {
            await presenter.onAppear()
        }
    }

    private var summaryContent: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.credentialExchangeIdleTitle) {
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
                        SettingsIconView(icon: iconForRelyingParty(presenter.exporterRelyingPartyIdentifier))
                    },
                    title: {
                        HStack(spacing: Spacing.s) {
                            Text(presenter.exporterDisplayName)
                            Image(.transferIcon)
                            Text(.appName)
                        }
                    },
                    description: {
                        Text(.credentialExchangeIdleDescription)
                            .foregroundStyle(.neutral600)
                    }
                )
                .settingsIconStyle(.border)
            }
            .listSectionSpacing(Spacing.m)

            Button(.credentialExchangeImportButton) {
                presenter.startImport()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
            .background(Color(UIColor.systemGroupedBackground))
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
                            icon.frame(width: 20)
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

    private func iconForRelyingParty(_ identifier: String) -> SettingsIcon {
        switch identifier {
        case "apple.com":
            .applePasswords
        case "com.8bit.bitwarden":
            .bitwarden
        default:
            .transferItems
        }
    }

    private var errorContent: some View {
        ResultView(
            kind: .failure,
            title: Text(.credentialExchangeErrorTitle),
            description: Text(.credentialExchangeIdleDescription)
        ) {
            Button(.commonClose) {
                presenter.onClose()
            }
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, *)
private final class PreviewInteractor: CredentialExchangeImportModuleInteracting {
    func convertCredentials(_ data: ASExportedCredentialData) throws(CredentialExchangeImportError) -> ExternalServiceImportResult {
        ExternalServiceImportResult(items: [], tags: [])
    }
}

@available(iOS 26.0, *)
#Preview {
    CredentialExchangeImportView(
        presenter: {
            let presenter = CredentialExchangeImportPresenter(
                interactor: PreviewInteractor(),
                onClose: {}
            )
            presenter.previewSetup(
                exporterDisplayName: "Apple Passwords",
                exporterRelyingPartyIdentifier: "apple.com",
                summary: [.login: 42, .paymentCard: 5, .secureNote: 3],
                tagsCount: 7,
                itemsConvertedToSecureNotes: 2
            )
            return presenter
        }()
    )
}
