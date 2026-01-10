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
            SettingsDetailsForm(.settingsEntrySubscription) {
                if let userIdentifier = presenter.userIdentifier{
                    userIdentifierSection(userIdentifier)
                }
                
                Section {
                    HStack {
                        Text(.manageSubscriptionItemsTitle)
                        
                        Spacer()
                        
                        Text(presenter.itemsCount, format: .number)
                            .monospacedDigit()
                            .padding(.trailing, Constants.digitValueTrailingPadding)
                    }
                    .font(.bodyEmphasized)
                }
                
                Section {
                    HStack {
                        Text(.manageSubscriptionBrowsersTitle)
                        
                        Spacer()
                        
                        Text(presenter.webBrowsersCount, format: .number)
                            .monospacedDigit()
                            .padding(.trailing, Constants.digitValueTrailingPadding)
                    }
                    .font(.bodyEmphasized)
                }
                
                Section {
                    HStack {
                        Text(.manageSubscriptionMultiDeviceSyncTitle)
                        
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
                Text(.manageSubscriptionTitle)
            },
            description: {
                VStack {
                    HStack(spacing: 0) {
                        Text(.manageSubscriptionPricePrefix)
                        
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
                                Text(.manageSubscriptionRenewDatePrefix) + Text(date).bold()
                            } else {
                                Text(.manageSubscriptionEndDatePrefix) + Text(date).bold()
                            }
                        }
                    }
                    .foregroundStyle(.neutral600)
                    
                    Text(.manageSubscriptionAppleInfo)
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
                    Text(.manageSubscriptionUserIdentifierTitle)
                        
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
            UIAction(title: String(localized: .commonCopy), handler: { _ in
                presenter.onUserIdentifierCopy()
            })
        ])
    }
}

#Preview {
    ManageSubscriptionView(presenter: .init(interactor: ModuleInteractorFactory.shared.manageSubscriptionInteractor()))
}
