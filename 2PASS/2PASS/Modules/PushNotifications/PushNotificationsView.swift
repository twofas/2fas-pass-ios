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
            SettingsDetailsForm(T.settingsEntryPushNotifications.localizedKey) {
                Section {
                    LabeledContent(T.settingsPushNotificationsStatusLabel.localizedKey, value: presenter.status)
                }
            } header: {
                SettingsHeaderView(
                    icon: .pushNotifications,
                    title: Text(T.settingsEntryPushNotifications.localizedKey),
                    description: Text(T.settingsEntryPushNotificationsDescription.localizedKey)
                )
            }
            
            Group {
                if presenter.canRequestForPermissions == false {
                    SettingsSystemLinkButton(
                        description: Text(T.settingsPushNotificationsOpenSystemSettingsDescription.localizedKey),
                        action: {
                            guard let url = presenter.systemSettingsURL else { return }
                            openURL(url)
                        }
                    )
                } else {
                    Button(T.settingsPushNotificationsEnableCta.localizedKey) {
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
