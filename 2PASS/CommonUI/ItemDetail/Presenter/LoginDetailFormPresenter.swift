// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

@Observable
final class LoginDetailFormPresenter: ItemDetailFormPresenter {
    
    struct URIPosition: Hashable, Identifiable {
        let id: UUID
        var uri: String
        var uriNormalized: URL?
        var match: PasswordURI.Match
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    private(set) var loginItem: LoginItemData
    
    private let passwordPlaceholder = "•••••••••••••••••"
    private var passwordDecrypted: String?
    
    var isPasswordVisible = false
    var isPasswordAvailable = false

    var username: String? {
        loginItem.username
    }
    
    var password: AttributedString?
    
    var notes: String? {
        loginItem.notes
    }
    
    var icon: PasswordIconType = .default
    var iconContent: IconContent?
    
    private var fetchingIconTask: Task<Void, Error>?

    var uri: [URIPosition] = []

    init(item: LoginItemData, configuration: ItemDetailFormConfiguration) {
        self.loginItem = item
        super.init(item: item, configuration: configuration)
        refreshValues()
    }
    
    var defaultIconContent: IconContent {
        .label(Config.defaultIconLabel(forName: name), color: nil)
    }
        
    func onDisappear() {
        fetchingIconTask?.cancel()
    }
    
    func onSelectUsername() {
        if let username, autoFillEnvironment?.isTextToInsert == true {
            flowController.autoFillTextToInsert(username)
        }
    }
    
    func onSelectPassword() {
        guard isPasswordAvailable, let passwordDecrypted else { return }
        
        if autoFillEnvironment?.isTextToInsert == true {
            flowController.autoFillTextToInsert(passwordDecrypted)
        } else {
            password = PasswordRenderer(password: passwordDecrypted.withZeroWidthSpaces).makeColorizedAttributedString()
        }
    }
    
    func onCopyUsername() {
        if let username {
            interactor.copy(username)
            toastPresenter.presentUsernameCopied()
        } else {
            toastPresenter.present(
                .passwordErrorCopyUsername,
                style: .failure
            )
        }
    }
    
    func onCopyPassword() {
        if let passwordDecrypted {
            interactor.copy(passwordDecrypted)
            toastPresenter.presentPasswordCopied()
        } else {
            toastPresenter.present(
                .passwordErrorCopyPassword,
                style: .failure
            )
        }
    }
    
    func onOpenURI(_ url: URL) {
        flowController.toOpenURI(url)
    }
    
    func onCopyURI(_ url: URL) {
        interactor.copy(url.absoluteString)
        toastPresenter.presentCopied()
    }
    
    func uriKey(at index: Int) -> LocalizedStringResource {
        uri.count == 1 ? .loginUriLabel : .loginUriLabel(Int32(index + 1))
    }
    
    func reload() {
        guard let newLoginItem = interactor.fetchItem(for: loginItem.id)?.asLoginItem else {
            return
        }
        self.loginItem = newLoginItem
        refreshValues()
    }
    
    private func refreshValues() {
        if let encryptedPassword = loginItem.password, let password = interactor.decryptSecureField(encryptedPassword, protectionLevel: loginItem.protectionLevel) {
            isPasswordAvailable = true
            passwordDecrypted = password
            self.password = AttributedString(passwordPlaceholder)
        } else {
            isPasswordAvailable = false
            passwordDecrypted = nil
            self.password = nil
        }
        
        uri = loginItem.uris?.map {
            URIPosition(
                id: .init(),
                uri: $0.uri,
                uriNormalized: interactor.normalizedURL(for: $0),
                match: $0.match
            )
        } ?? []
        icon = loginItem.iconType
        
        switch loginItem.iconType {
        case .label(labelTitle: let title, labelColor: let color):
            iconContent = .label(title, color: color)
            
        case .customIcon(let url):
            iconContent = defaultIconContent
            fetchIcon(from: url, name: loginItem.name ?? "")
            
        case .domainIcon:
            iconContent = defaultIconContent
            
            if let url = loginItem.iconType.iconURL {
                fetchIcon(from: url, name: loginItem.name ?? "")
            }
        }
    }
    
    private func fetchIcon(from iconURL: URL, name: String) {
        fetchingIconTask?.cancel()
        fetchingIconTask = Task { @MainActor in
            if let imageData = try? await interactor.fetchIconImage(from: iconURL), let image = UIImage(data: imageData) {
                iconContent = .icon(image)
            }
        }
    }
}
