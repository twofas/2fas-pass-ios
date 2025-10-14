// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

enum SettingsIcon {
    case app
    case lock
    case customization
    case autofill
    case deletedData
    case subscription
    case knownWebBrowsers
    case pushNotifications
    case sync
    case importExport
    case transferPasswords
    case about
    case help
    case discord
    case debug
    case `import`
    case share
    case rate
    case eventLog
    case appState
    case modifyState
    case biometry
    case password
    case recoveryKit
    case generate
    case invite
    case privacyPolicy
    case termsOfUse
    case openSourceLicenses
    case libraries
    case github
    case x
    case youtube
    case linkedIn
    case reddit
    case facebook
    case paymentsDebug
    case onePassword
    case chrome
    case bitwarden
    case dashlane
    case lastPass
    case proton
    case applePasswords
    case twoFASAuth
    case firefox
    case keePass
    case keePassXC
    case microsoftEdge
}

enum SettingIconStyle {
    case fill
    case border
}

struct SettingsIconView: View {
    
    let icon: SettingsIcon
    
    @Environment(\.controlSize) private var controlSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.settingsIconStyle) private var settingsIconStyle
    
    var body: some View {
        content
            .foregroundStyle(.secondary)
            .font(.system(size: fontSize))
            .frame(width: size, height: size)
            .background {
                switch settingsIconStyle {
                case .border:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(colorScheme == .dark ? .neutral800 : .neutral200, lineWidth: 0.5)
                        .fill(colorScheme == .dark ? .baseStatic0 : .clear)
                case .fill:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.primary)
                }
            }
            .foregroundStyle(.accent, colorScheme == .dark ? .neutral950 : .neutral50)
    }
    
    private var fontSize: CGFloat {
        switch controlSize {
        case .small, .mini, .regular: 14
        case .large, .extraLarge: 29
        default: 14
        }
    }
    
    private var cornerRadius: CGFloat {
        switch controlSize {
        case .small, .mini, .regular: 8
        case .large, .extraLarge: 12
        default: 8
        }
    }
    
    private var size: CGFloat {
        switch controlSize {
        case .small, .mini, .regular: 28
        case .large, .extraLarge: 60
        default: 28
        }
    }
    
    private var image: Image {
        switch icon {
        case .lock:
            Image(systemName: "lock.fill")
        case .customization:
            Image(systemName: "gearshape.fill")
        case .autofill:
            Image(systemName: "rectangle.and.pencil.and.ellipsis")
        case .deletedData:
            Image(systemName: "trash.fill")
        case .subscription:
            Image(systemName: "creditcard")
        case .knownWebBrowsers:
            Image(systemName: "laptopcomputer.and.arrow.down")
        case .pushNotifications:
            Image(systemName: "bell.badge.fill")
        case .sync:
            if #available(iOS 18, *) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
            } else {
                Image(systemName: "clock.arrow.circlepath")
            }
        case .importExport:
            Image(systemName: "rectangle.portrait.and.arrow.right")
        case .transferPasswords:
            Image(systemName: "iphone.gen1")
        case .about:
            Image(systemName: "info.circle.fill")
        case .help:
            Image(systemName: "questionmark.circle.fill")
        case .debug:
            Image(systemName: "ladybug.fill")
        case .import:
            Image(systemName: "square.and.arrow.down.fill")
        case .share:
            Image(systemName: "person.2.fill")
        case .rate:
            Image(systemName: "star.fill")
        case .eventLog:
            Image(systemName: "star.square.fill")
        case .appState:
            Image(systemName: "square.stack.3d.up.fill")
        case .modifyState:
            Image(systemName: "switch.2")
        case .biometry:
            Image(systemName: "faceid")
        case .password:
            Image(systemName: "key")
        case .recoveryKit:
            Image(systemName: "hand.raised")
        case .generate:
            Image(systemName: "plus.square.on.square")
        case .discord:
            Image(.discordIcon)
        case .invite:
            Image(systemName: "plus.circle.fill")
        case .privacyPolicy:
            Image(systemName: "eye.slash")
        case .termsOfUse:
            Image(systemName: "newspaper.fill")
        case .openSourceLicenses:
            Image(systemName: "door.right.hand.open")
        case .libraries:
            Image(systemName: "books.vertical")
        case .github:
            Image(.githubIcon)
        case .app:
            Image(.smallShield)
        case .x:
            Image(.xIcon)
        case .youtube:
            Image(.youtubeIcon)
        case .linkedIn:
            Image(.linkedinIcon)
        case .reddit:
            Image(.redditIcon)
        case .facebook:
            Image(.facebookIcon)
        case .paymentsDebug:
            Image(systemName: "creditcard.fill")
        case .onePassword:
            Image(._1PasswordIcon)
        case .chrome:
            Image(.chromeIcon)
        case .bitwarden:
            Image(.bitwardenIcon)
        case .dashlane:
            Image(.dashlaneIcon)
        case .lastPass:
            Image(.lastpassIcon)
        case .proton:
            Image(.protonIcon)
        case .applePasswords:
            Image(.applePasswordsIcon)
        case .twoFASAuth:
            Image(.twoFASAuth)
        case .firefox:
            Image(.firefoxIcon)
        case .keePass:
            Image(.keepassIcon)
        case .keePassXC:
            Image(.keepassxcIcon)
        case .microsoftEdge:
            Image(.microsoftedgeIcon)
        }
    }
    
    @ViewBuilder
    private var content: some View {
        switch icon {
        case .sync:
            image.offset(x: size * 0.01)
        case .app:
            image
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
        case .bitwarden, .onePassword, .chrome, .proton, .dashlane, .lastPass, .applePasswords, .firefox, .keePass, .keePassXC, .microsoftEdge:
            image
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
        default:
            image.renderingMode(settingsIconStyle == .fill ? .template : .original)
        }
    }
}

#Preview {
    VStack {
        SettingsIconView(icon: .sync)
            .controlSize(.small)
            .overlay {
                Rectangle()
                    .stroke(lineWidth: 1)
                    .frame(width: 1)
            }
            .overlay {
                Rectangle()
                    .stroke(lineWidth: 1)
                    .frame(height: 1)
            }
        
        SettingsIconView(icon: .sync)
            .controlSize(.large)
            .overlay {
                Rectangle()
                    .stroke(lineWidth: 1)
                    .frame(width: 1)
            }
            .overlay {
                Rectangle()
                    .stroke(lineWidth: 1)
                    .frame(height: 1)
            }
        
        SettingsIconView(icon: .sync)
            .controlSize(.large)
    }
    .foregroundStyle(Color.black.opacity(0.5))
}

extension View {
    
    func settingsIconStyle(_ style: SettingIconStyle) -> some View {
        environment(\.settingsIconStyle, style)
    }
}

struct SettingsIconStyleEnvironemntKey: EnvironmentKey {
    static let defaultValue: SettingIconStyle = .fill
}

extension EnvironmentValues {
    
    var settingsIconStyle: SettingIconStyle {
        get {
            self[SettingsIconStyleEnvironemntKey.self]
        } set {
            self[SettingsIconStyleEnvironemntKey.self] = newValue
        }
    }
}
