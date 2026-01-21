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
                            title: .settingsEntrySecurity
                        )
                    }
                    
                    Button {
                        presenter.onCustomization()
                    } label: {
                        SettingsRowView(
                            icon: .customization,
                            title: .settingsEntryCustomization
                        )
                    }
                    
                    Button {
                        presenter.onAutoFill()
                    } label: {
                        SettingsRowView(
                            icon: .autofill,
                            title: .settingsEntryAutofill,
                            additionalInfo: Text(presenter.autoFillStatus)
                        )
                    }
                    
                    Button {
                        presenter.onDeletedData()
                    } label: {
                        SettingsRowView(
                            icon: .deletedData,
                            title: .settingsEntryTrash
                        )
                    }
                } header: {
                    Text(.settingsHeaderMobileApp)
                        .padding(.top, Spacing.xll)
                }
                
                Section(.settingsHeaderBrowserExtension) {
                    Button {
                        presenter.onKnownWebBrowsers()
                    } label: {
                        SettingsRowView(
                            icon: .knownWebBrowsers,
                            title: .settingsEntryKnownBrowsers
                        )
                    }
                    
                    Button {
                        presenter.onPushNotifications()
                    } label: {
                        SettingsRowView(
                            icon: .pushNotifications,
                            title: .settingsEntryPushNotifications,
                            additionalInfo: Text(presenter.pushNotificationsStatus)
                        )
                    }
                }
                
                Section(.settingsHeaderBackup) {
                    Button {
                        presenter.onSync()
                    } label: {
                        SettingsRowView(
                            icon: .sync,
                            title: .settingsEntryCloudSync,
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
                            title: .settingsEntryImportExport
                        )
                    }
                    
                    Button {
                        presenter.onTransferItems()
                    } label: {
                        SettingsRowView(
                            icon: .transferItems,
                            title: .settingsEntryTransferFromOtherApps
                        )
                    }
                }
                
                Section(.settingsManageTokensTitle) {
                    Button {
                        if presenter.is2FASAuthInstalled {
                            openURL(Config.twofasAuthOpenLink)
                        } else {
                            openURL(Config.twofasAuthAppStoreLink)
                        }
                    } label: {
                        SettingsRowView(
                            icon: .twoFASAuth,
                            title: presenter.is2FASAuthInstalled ? .settings2FasOpen : .settings2FasGet,
                            actionIcon: .link
                        )
                    }
                }
                
                Section(.settingsHeaderAbout) {
                    if presenter.isPaidUser {
                        Button {
                            presenter.onSubscription()
                        } label: {
                            SettingsRowView(
                                icon: .subscription,
                                title: .settingsEntrySubscription,
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
                                title: .settingsEntrySubscription,
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
                            title: .settingsEntryAbout
                        )
                    }
                    
                    Button {
                        openURL(URL(string: "https://2fas.com/help-center/")!)
                    } label: {
                        SettingsRowView(
                            icon: .help,
                            title: .settingsEntryHelpCenter,
                            actionIcon: .link
                        )
                    }
                    
                    Button {
                        openURL(URL(string: "https://2fas.com/discord")!)
                    } label: {
                        SettingsRowView(
                            icon: .discord,
                            title: .settingsEntryDiscord,
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
            .navigationTitle(.settingsTitle)
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
