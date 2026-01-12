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
        SettingsDetailsForm(.settingsEntrySecurity) {
            Section {
                Button {
                    presenter.onChangePassword()
                } label: {
                    Text(.settingsEntryChangePassword)
                }
                .disabled(presenter.lockInteraction)
                
                Toggle(.settingsEntryBiometricsToggle, isOn: $presenter.isBiometryEnabled)
                    .disabled(
                        !presenter.isBiometryAvailable || !presenter.enableBiometryToggle || presenter.lockInteraction
                    )
                    .tint(.accentColor)
                
            } header: {
                Text(.settingsEntryAppAccess)
                    .padding(.top, Spacing.m)
                
            } footer: {
                if presenter.isBiometryAvailable {
                    Text(.settingsEntryBiometricsDescription)
                } else {
                    Text(.settingsEntryBiometricsNotAvailable)
                }
            }
            
            Section {
                Button {
                    presenter.onLimitOfFailedAttempts()
                } label: {
                    SettingsRowView(title: .settingsEntryAppLockAttempts)
                }
                .disabled(presenter.lockInteraction)
            } footer: {
                Text(.settingsEntryAppLockAttemptsFooter)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onDefaultSecurityTier()
                } label: {
                    SettingsRowView(
                        title: .settingsEntryProtectionLevel,
                        additionalInfo: {
                            Label {
                                Text(presenter.defaultSecurityTier.title)
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
                Text(.settingsEntryDataAccess)
            } footer: {
                Text(.settingsEntryProtectionLevelDescription)
                    .settingsFooter()
            }
            
            Section {
                Button {
                    presenter.onVaultDecryptionKit()
                } label: {
                    SettingsRowView(
                        title: .settingsEntryDecryptionKit
                    )
                }
                .disabled(presenter.lockInteraction)
            } header: {
                Text(.commonOther)
            } footer: {
                Text(.settingsEntryDecryptionKitDescription)
                    .settingsFooter()
            }
        }
    }
}

#Preview {
    AppSecurityRouter.buildView()
}
