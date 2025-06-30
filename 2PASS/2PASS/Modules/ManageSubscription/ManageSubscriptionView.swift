// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let digitValueTrailingPadding: CGFloat = 5
}

struct ManageSubscriptionView: View {
    
    @State
    var presenter: ManageSubscriptionPresenter
    
    @State
    private var showUserIdentifierMenu: Bool = false
    
    var body: some View {
        VStack {
            SettingsDetailsForm(Text(T.settingsEntrySubscription.localizedKey)) {
                if let userIdentifier = presenter.userIdentifier{
                    userIdentifierSection(userIdentifier)
                }
                
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(T.manageSubscriptionItemsTitle.localizedKey)
                            Text(T.manageSubscriptionItemsSubtitle.localizedKey)
                                .font(.footnote)
                                .foregroundStyle(.neutral600)
                        }
                        
                        Spacer()
                        
                        Text(presenter.itemsCount, format: .number)
                            .monospacedDigit()
                            .padding(.trailing, Constants.digitValueTrailingPadding)
                    }
                    .font(.bodyEmphasized)
                }
                
                Section {
                    HStack {
                        Text(T.manageSubscriptionBrowsersTitle.localizedKey)
                        
                        Spacer()
                        
                        Text(presenter.webBrowsersCount, format: .number)
                            .monospacedDigit()
                            .padding(.trailing, Constants.digitValueTrailingPadding)
                    }
                    .font(.bodyEmphasized)
                }
                
                Section {
                    HStack {
                        Text(T.manageSubscriptionMultiDeviceSyncTitle.localizedKey)
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.success500)
                    }
                    .font(.bodyEmphasized)
                }
            } header: {
                header
            }
            .listSectionSpacing(Spacing.m)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .task {
            await presenter.onAppear()
        }
    }
    
    @ViewBuilder
    private var header: some View {
        SettingsHeaderView(
            icon: {
                SettingsIconView(icon: .app)
            },
            title: {
                Text(T.manageSubscriptionTitle.localizedKey)
            },
            description: {
                VStack {
                    HStack(spacing: 0) {
                        Text(T.manageSubscriptionPricePrefix.localizedKey)
                        
                        if let price = presenter.renewPrice {
                            Text(price)
                                .bold()
                        } else {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.neutral500)
                        }
                    }
                    .foregroundStyle(.neutral600)

                    Group {
                        if let date = presenter.renewDate {
                            if presenter.willRenew {
                                Text(T.manageSubscriptionRenewDatePrefix.localizedKey) + Text(date).bold()
                            } else {
                                Text(T.manageSubscriptionEndDatePrefix.localizedKey) + Text(date).bold()
                            }
                        }
                    }
                    .foregroundStyle(.neutral600)
                    
                    Text(T.manageSubscriptionAppleInfo.localizedKey)
                        .foregroundStyle(.neutral400)
                }
            }
        )
        .settingsIconStyle(.border)
    }
    
    @ViewBuilder
    private func userIdentifierSection(_ userIdentifier: String) -> some View {
        Section {
            Button {
                showUserIdentifierMenu = true
            } label: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(T.manageSubscriptionUserIdentifierTitle.localizedKey)
                        
                    Text(userIdentifier.withZeroWidthSpaces)
                        .font(.footnote)
                        .foregroundStyle(.neutral600)
                }
                .foregroundStyle(.neutral950)
            }
            .font(.bodyEmphasized)
            .listRowBackground(showUserIdentifierMenu == true ? Color.neutral100 : nil)
        }
        .editMenu($showUserIdentifierMenu, actions: [
            UIAction(title: T.commonCopy, handler: { _ in
                presenter.onUserIdentifierCopy()
            })
        ])
    }
}

#Preview {
    ManageSubscriptionView(presenter: .init(interactor: ModuleInteractorFactory.shared.manageSubscriptionInteractor()))
}
