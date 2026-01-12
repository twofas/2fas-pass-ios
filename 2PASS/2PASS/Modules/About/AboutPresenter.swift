// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import SwiftUI
import CommonUI
import Common

enum AboutDestination: RouterDestination {
    case viewLogs
}

@Observable @MainActor
final class AboutPresenter {
    
    var destination: AboutDestination?
    
    var anonymousCrashReports: Bool {
        get {
            interactor.isCrashReportsEnabled
        }
        set {
            interactor.setCrashReportsEnabled(newValue)
        }
    }
    
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
        let title: LocalizedStringResource
        let url: URL
    }
}

extension AboutPresenter.LinkItem {
    static let rate = AboutPresenter.LinkItem(icon: .rate, title: .aboutRateUsAppStore, url: Config.appStoreURL)
    static let privacyPolicy = AboutPresenter.LinkItem(icon: .privacyPolicy, title: .aboutPrivacyPolicy, url: Config.privacyPolicyURL)
    static let termsOfUse = AboutPresenter.LinkItem(icon: .termsOfUse, title: .aboutTermsOfUse, url: Config.tosURL)
    static let libraries = AboutPresenter.LinkItem(icon: .libraries, title: .aboutLibrariesWeUse, url: Config.openSourceLicencesURL)

    static let discord = AboutPresenter.LinkItem(icon: .discord, title: .aboutDiscord, url: URL(string: "https://2fas.com/discord/")!)
    static let github = AboutPresenter.LinkItem(icon: .github, title: .aboutGithub, url: URL(string: "https://github.com/twofas")!)
    static let x = AboutPresenter.LinkItem(icon: .x, title: .aboutX, url: URL(string: "https://x.com/2fas_com")!)
    static let youtube = AboutPresenter.LinkItem(icon: .youtube, title: .aboutYoutube, url: URL(string: "https://www.youtube.com/@2FAS")!)
    static let linkedIn = AboutPresenter.LinkItem(icon: .linkedIn, title: .aboutLinkedin, url: URL(string: "https://www.linkedin.com/company/2fasapp/")!)
    static let reddit = AboutPresenter.LinkItem(icon: .reddit, title: .aboutReddit, url: URL(string: "https://www.reddit.com/r/2fas_com/")!)
    static let facebook = AboutPresenter.LinkItem(icon: .facebook, title: .aboutFacebook, url: URL(string: "https://www.facebook.com/twofas")!)
}
