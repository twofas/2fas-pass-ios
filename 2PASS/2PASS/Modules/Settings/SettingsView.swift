// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct SettingsView: View {
    
    @State
    var presenter: SettingsPresenter
    
    @Environment(\.openURL)
    private var openURL
            
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        presenter.onSecurity()
                    } label: {
                        SettingsRowView(
                            icon: .lock,
                            title: T.settingsEntrySecurity.localizedKey
                        )
                    }
                    
                    Button {
                        presenter.onCustomization()
                    } label: {
                        SettingsRowView(
                            icon: .customization,
                            title: T.settingsEntryCustomization.localizedKey
                        )
                    }
                    
                    Button {
                        presenter.onAutoFill()
                    } label: {
                        SettingsRowView(
                            icon: .autofill,
                            title: T.settingsEntryAutofill.localizedKey,
                            additionalInfo: Text(presenter.autoFillStatus)
                        )
                    }
                    
                    Button {
                        presenter.onDeletedData()
                    } label: {
                        SettingsRowView(
                            icon: .deletedData,
                            title: T.settingsEntryTrash.localizedKey
                        )
                    }
                } header: {
                    Text(T.settingsHeaderMobileApp.localizedKey)
                        .padding(.top, Spacing.xll)
                }
                
                Section(T.settingsHeaderBrowserExtension.localizedKey) {
                    Button {
                        presenter.onKnownWebBrowsers()
                    } label: {
                        SettingsRowView(
                            icon: .knownWebBrowsers,
                            title: T.settingsEntryKnownBrowsers.localizedKey
                        )
                    }
                    
                    Button {
                        presenter.onPushNotifications()
                    } label: {
                        SettingsRowView(
                            icon: .pushNotifications,
                            title: T.settingsEntryPushNotifications.localizedKey,
                            additionalInfo: Text(presenter.pushNotificationsStatus)
                        )
                    }
                }
                
                Section(T.settingsHeaderBackup.localizedKey) {
                    Button {
                        presenter.onSync()
                    } label: {
                        SettingsRowView(
                            icon: .sync,
                            title: T.settingsEntryCloudSync.localizedKey,
                            additionalInfo: {
                                if presenter.hasSyncError {
                                    BadgeView(value: 1)
                                } else {
                                    Text(presenter.syncStatus)
                                }
                            }
                        )
                    }
                    
                    Button {
                        presenter.onImportExport()
                    } label: {
                        SettingsRowView(
                            icon: .importExport,
                            title: T.settingsEntryImportExport.localizedKey
                        )
                    }
                    
                    Button {
                        presenter.onTransferItems()
                    } label: {
                        SettingsRowView(
                            icon: .transferItems,
                            title: T.settingsEntryTransferFromOtherApps.localizedKey
                        )
                    }
                }
                
                Section(T.settingsManageTokensTitle) {
                    Button {
                        if presenter.is2FASAuthInstalled {
                            openURL(Config.twofasAuthOpenLink)
                        } else {
                            openURL(Config.twofasAuthAppStoreLink)
                        }
                    } label: {
                        SettingsRowView(
                            icon: .twoFASAuth,
                            title: presenter.is2FASAuthInstalled ? T.settings2fasOpen.localizedKey : T.settings2fasGet.localizedKey,
                            actionIcon: .link
                        )
                    }
                }
                
                Section(T.settingsHeaderAbout.localizedKey) {
                    if presenter.isPaidUser {
                        Button {
                            presenter.onSubscription()
                        } label: {
                            SettingsRowView(
                                icon: .subscription,
                                title: T.settingsEntrySubscription.localizedKey,
                                actionIcon: .chevron,
                                additionalInfo: Text(presenter.subscriptionStatus)
                            )
                        }
                    } else {
                        Button {
                            presenter.onSubscription()
                        } label: {
                            SettingsRowView(
                                icon: .subscription,
                                title: T.settingsEntrySubscription.localizedKey,
                                actionIcon: .chevron,
                                additionalInfo: Text(presenter.subscriptionStatus)
                            )
                        }
                    }
                    
                    Button {
                        presenter.onAbout()
                    } label: {
                        SettingsRowView(
                            icon: .about,
                            title: T.settingsEntryAbout.localizedKey
                        )
                    }
                    
                    Button {
                        openURL(URL(string: "https://2fas.com/help-center/")!)
                    } label: {
                        SettingsRowView(
                            icon: .help,
                            title: T.settingsEntryHelpCenter.localizedKey,
                            actionIcon: .link
                        )
                    }
                    
                    Button {
                        openURL(URL(string: "https://2fas.com/discord")!)
                    } label: {
                        SettingsRowView(
                            icon: .discord,
                            title: T.settingsEntryDiscord.localizedKey,
                            actionIcon: .link
                        )
                    }
                }
                
                #if PROD
                #else
                Section {
                    Button {
                        presenter.onDebug()
                    } label: {
                        SettingsRowView(
                            icon: .debug,
                            title: Text("Debug" as String)
                        )
                    }
                }
                #endif
            }
            .router(router: SettingsRouter(), destination: $presenter.destination)
            .navigationTitle(T.settingsTitle.localizedKey)
            .onAppear {
                presenter.onAppear()
            }
            .task {
                await presenter.observeAutoFillStatusChanged()
            }
            .task {
                await presenter.observePushNotificationsStatusChanged()
            }
            .task {
                await presenter.observeSyncStateChanged()
            }
        }
    }
}

#Preview {
    SettingsRouter.buildView()
}
