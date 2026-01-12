// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct PushNotificationsView: View {
    
    @State
    var presenter: PushNotificationsPresenter
    
    @Environment(\.openURL)
    private var openURL
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsDetailsForm(.settingsEntryPushNotifications) {
                Section {
                    LabeledContent(String(localized: .settingsPushNotificationsStatusLabel), value: presenter.status)
                }
            } header: {
                SettingsHeaderView(
                    icon: .pushNotifications,
                    title: Text(.settingsEntryPushNotifications),
                    description: Text(.settingsEntryPushNotificationsDescription)
                )
            }
            
            Group {
                if presenter.canRequestForPermissions == false {
                    SettingsSystemLinkButton(
                        description: Text(.settingsPushNotificationsOpenSystemSettingsDescription),
                        action: {
                            guard let url = presenter.systemSettingsURL else { return }
                            openURL(url)
                        }
                    )
                } else {
                    Button(.settingsPushNotificationsEnableCta) {
                        presenter.turnOn()
                    }
                    .buttonStyle(.filled)
                    .controlSize(.large)
                    .padding(.horizontal, Spacing.xl)
                }
            }
            .padding(.vertical, Spacing.xl)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .ignoresSafeArea(.keyboard)
        .task {
            await presenter.observePushNotificationsStatusChanged()
        }
    }
}

#Preview {
    PushNotificationsView(presenter: .init(interactor: ModuleInteractorFactory.shared.pushNotificationsModuleInteractor()))
}
