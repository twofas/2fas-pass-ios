// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct AppSecurityView: View {

    @State
    var presenter: AppSecurityPresenter
    
    var body: some View {
        content
            .onAppear {
                presenter.onAppear()
            }
            .router(router: AppSecurityRouter(), destination: $presenter.destination)
    }
    
    @ViewBuilder
    private var content: some View {
        SettingsDetailsForm(T.settingsEntrySecurity.localizedKey) {
            Section {
                Button {
                    presenter.onChangePassword()
                } label: {
                    Text(T.settingsEntryChangePassword.localizedKey)
                }
                .disabled(presenter.lockInteraction)
                
                Toggle(T.settingsEntryBiometricsToggle.localizedKey, isOn: $presenter.isBiometryEnabled)
                    .disabled(
                        !presenter.isBiometryAvailable || !presenter.enableBiometryToggle || presenter.lockInteraction
                    )
                
            } header: {
                Text(T.settingsEntryAppAccess.localizedKey)
                    .padding(.top, Spacing.m)
                
            } footer: {
                if presenter.isBiometryAvailable {
                    Text(T.settingsEntryBiometricsDescription.localizedKey)
                } else {
                    Text(T.settingsEntryBiometricsNotAvailable.localizedKey)
                }
            }
            
            Section {
                Button {
                    presenter.onLimitOfFailedAttempts()
                } label: {
                    SettingsRowView(title: T.settingsEntryAppLockAttempts.localizedKey)
                }
                .disabled(presenter.lockInteraction)
            } footer: {
                Text(T.settingsEntryAppLockAttemptsFooter.localizedKey)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onDefaultSecurityTier()
                } label: {
                    SettingsRowView(
                        title: T.settingsEntryProtectionLevel.localizedKey,
                        additionalInfo: {
                            Label {
                                Text(presenter.defaultSecurityTier.title.localizedKey)
                            } icon: {
                                presenter.defaultSecurityTier.icon
                                    .renderingMode(.template)
                                    .foregroundStyle(.accent)
                            }
                            .labelStyle(.rowValue)
                        }
                    )
                }
                .disabled(presenter.lockInteraction)
            } header: {
                Text(T.settingsEntryDataAccess.localizedKey)
            } footer: {
                Text(T.settingsEntryProtectionLevelDescription.localizedKey)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onVaultDecryptionKit()
                } label: {
                    SettingsRowView(
                        title: T.settingsEntryDecryptionKit.localizedKey
                    )
                }
                .disabled(presenter.lockInteraction)
            } header: {
                Text(T.commonOther.localizedKey)
            } footer: {
                Text(T.settingsEntryDecryptionKitDescription.localizedKey)
                    .settingsFooter()
            }
        }
    }
}

#Preview {
    AppSecurityRouter.buildView()
}
