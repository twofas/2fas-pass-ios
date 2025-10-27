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
        SettingsDetailsForm(T.settingsEntryAbout.localizedKey) {
            general
            share
            connect
            crashReporting
        } header: {
            SettingsHeaderView(
                icon: .app,
                title: Text(T.aboutTagline.localizedKey),
                description: Text(T.aboutVersionIos(presenter.appVersion).localizedKey)
            )
            .settingsIconStyle(.border)
        }
        .router(router: AboutRouter(), destination: $presenter.destination)
    }
    
    private var general: some View {
        Section(T.aboutSectionGeneral.localizedKey) {
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
        Section(T.aboutSectionShare.localizedKey) {
            ShareLink(
                item: URL(string: "http://2fas.com/pass/download")!,
                subject: Text(T.shareLinkSubject.localizedKey),
                message: Text(T.shareLinkMessage.localizedKey),
                label: {
                    SettingsRowView(
                        icon: .invite,
                        title: T.aboutInviteFriends.localizedKey,
                        actionIcon: nil
                    )
                    .titleButtonStyle()
                }
            )
        }
    }
    
    private var connect: some View {
        Section(T.aboutSectionConnect.localizedKey) {
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
            Button(T.aboutSendLogsCta.localizedKey) {
                presenter.onSendLogs()
            }
            Toggle(T.aboutSendCrashReports.localizedKey, isOn: $presenter.anonymousCrashReports)
                .tint(.accentColor)
        } header: {
            Text(T.aboutSectionCrashReporting.localizedKey)
        } footer: {
            Text(T.aboutCrashReportsDescription.localizedKey)
                .settingsFooter()
                .padding(.bottom, Spacing.xll)
        }
    }
}

#Preview {
    AboutView(presenter: .init(interactor: ModuleInteractorFactory.shared.aboutModuleInteractor()))
}
