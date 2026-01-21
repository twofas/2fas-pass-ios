// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct AboutView: View {

    @State
    var presenter: AboutPresenter
    
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        SettingsDetailsForm(.settingsEntryAbout) {
            general
            share
            connect
            crashReporting
        } header: {
            SettingsHeaderView(
                icon: .app,
                title: Text(.aboutTagline),
                description: Text(.aboutVersionIos(presenter.appVersion))
            )
            .settingsIconStyle(.border)
        }
        .router(router: AboutRouter(), destination: $presenter.destination)
    }
    
    private var general: some View {
        Section(.aboutSectionGeneral) {
            ForEach(presenter.generalLinks) { link in
                Button {
                    openURL(link.url)
                } label: {
                    SettingsRowView(
                        icon: link.icon,
                        title: link.title,
                        actionIcon: .link
                    )
                }
            }
        }
    }
    
    private var share: some View {
        Section(.aboutSectionShare) {
            ShareLink(
                item: URL(string: "http://2fas.com/pass/download")!,
                subject: Text(.shareLinkSubject),
                message: Text(.shareLinkMessage),
                label: {
                    SettingsRowView(
                        icon: .invite,
                        title: .aboutInviteFriends,
                        actionIcon: nil
                    )
                    .titleButtonStyle()
                }
            )
        }
    }
    
    private var connect: some View {
        Section(.aboutSectionConnect) {
            ForEach(presenter.connectLinks) { link in
                Button {
                    openURL(link.url)
                } label: {
                    SettingsRowView(
                        icon: link.icon,
                        title: link.title,
                        actionIcon: .link
                    )
                    .settingsIconStyle(.border)
                }
            }
        }
    }
    
    private var crashReporting: some View {
        Section {
            Button(.aboutSendLogsCta) {
                presenter.onSendLogs()
            }
            Toggle(.aboutSendCrashReports, isOn: $presenter.anonymousCrashReports)
                .tint(.accentColor)
        } header: {
            Text(.aboutSectionCrashReporting)
        } footer: {
            Text(.aboutCrashReportsDescription)
                .settingsFooter()
                .padding(.bottom, Spacing.xll)
        }
    }
}

#Preview {
    AboutView(presenter: .init(interactor: ModuleInteractorFactory.shared.aboutModuleInteractor()))
}
