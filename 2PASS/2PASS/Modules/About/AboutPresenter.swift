// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import SwiftUI
import CommonUI

enum AboutDestination: RouterDestination {
    case viewLogs
}

@Observable @MainActor
final class AboutPresenter {
    
    var destination: AboutDestination?
    var anonymousCrashReports = false
    
    var appVersion: String {
        interactor.appVersion
    }
    
    let generalLinks: [LinkItem] = [
        .rate,
        .privacyPolicy,
        .termsOfUse,
        .libraries
    ]
    
    let connectLinks: [LinkItem] = [
        .discord,
        .github,
        .x,
        .youtube,
        .linkedIn,
        .reddit,
        .facebook
    ]
    
    private let interactor: AboutModuleInteracting
    
    init(interactor: AboutModuleInteracting) {
        self.interactor = interactor
    }
    
    func onSendLogs() {
        destination = .viewLogs
    }
}

extension AboutPresenter {
    
    struct LinkItem: Identifiable {
        let id = UUID()
        let icon: SettingsIcon
        let title: LocalizedStringKey
        let url: URL
    }
}

extension AboutPresenter.LinkItem {
    static let rate = AboutPresenter.LinkItem(icon: .rate, title: T.aboutRateUsAppStore.localizedKey, url: URL(string: "https://apps.apple.com/us/app/2fas-pass-password-manager/id6504464955")!)
    static let privacyPolicy = AboutPresenter.LinkItem(icon: .privacyPolicy, title: T.aboutPrivacyPolicy.localizedKey, url: URL(string: "https://2fas.com/pass/privacy-policy")!)
    static let termsOfUse = AboutPresenter.LinkItem(icon: .termsOfUse, title: T.aboutTermsOfUse.localizedKey, url: URL(string: "https://2fas.com/pass/terms-of-service")!)
    static let libraries = AboutPresenter.LinkItem(icon: .libraries, title: T.aboutLibrariesWeUse.localizedKey, url: URL(string: "https://2fas.com/pass/open-source-licenses")!)

    static let discord = AboutPresenter.LinkItem(icon: .discord, title: T.aboutDiscord.localizedKey, url: URL(string: "https://2fas.com/discord/")!)
    static let github = AboutPresenter.LinkItem(icon: .github, title: T.aboutGithub.localizedKey, url: URL(string: "https://2fas.com")!)
    static let x = AboutPresenter.LinkItem(icon: .x, title: T.aboutX.localizedKey, url: URL(string: "https://x.com/2fas_com")!)
    static let youtube = AboutPresenter.LinkItem(icon: .youtube, title: T.aboutYoutube.localizedKey, url: URL(string: "https://www.youtube.com/@2FAS")!)
    static let linkedIn = AboutPresenter.LinkItem(icon: .linkedIn, title: T.aboutLinkedin.localizedKey, url: URL(string: "https://www.linkedin.com/company/2fasapp/")!)
    static let reddit = AboutPresenter.LinkItem(icon: .reddit, title: T.aboutReddit.localizedKey, url: URL(string: "https://www.reddit.com/r/2fas_com/")!)
    static let facebook = AboutPresenter.LinkItem(icon: .facebook, title: T.aboutFacebook.localizedKey, url: URL(string: "https://www.facebook.com/twofas")!)
}
