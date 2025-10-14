// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data
import SwiftUI

@Observable
final class ViewPasswordPresenter {
    private let itemID: ItemID
    private let flowController: ViewPasswordFlowControlling
    private let interactor: ViewPasswordModuleInteracting
    private let notificationCenter: NotificationCenter
    private let toastPresenter: ToastPresenter
    private let autoFillEnvironment: AutoFillEnvironment?
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private let passwordPlaceholder = "•••••••••••••••••"
    private var passwordDecrypted: String?
    
    var isPasswordVisible = false
    var isPasswordAvailable = false
    var isUsernameAvailable = false
    var name: String = ""
    var username: String?
    var password: AttributedString?
    var notes: String?
    var protectionLevel: ItemProtectionLevel = .topSecret
    var icon: PasswordIconType = .default
    var iconContent: IconContent?
    var createdAt: String = ""
    var modifiedAt: String = ""
    var tags: String?
    
    private var fetchingIconTask: Task<Void, Error>?
    
    var uri: [ViewPasswordURIPosition] = []
    
    init(
        itemID: ItemID,
        flowController: ViewPasswordFlowControlling,
        interactor: ViewPasswordModuleInteracting,
        autoFillEnvironment: AutoFillEnvironment? = nil
    ) {
        self.itemID = itemID
        self.flowController = flowController
        self.interactor = interactor
        self.notificationCenter = .default
        self.toastPresenter = .shared
        self.autoFillEnvironment = autoFillEnvironment
        
        notificationCenter.addObserver(self, selector: #selector(syncFinished), name: .webDAVStateChange, object: nil)
        notificationCenter.addObserver(self, selector: #selector(iCloudSyncFinished), name: .cloudStateChanged, object: nil)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension ViewPasswordPresenter {
    func onAppear() {
        reload()
    }
    
    func onDisappear() {
        fetchingIconTask?.cancel()
    }
    
    private func fetchIcon(from iconURL: URL, name: String) {
        fetchingIconTask?.cancel()
        fetchingIconTask = Task { @MainActor in
            if let imageData = try? await interactor.fetchIconImage(from: iconURL), let image = UIImage(data: imageData) {
                iconContent = .icon(image)
            }
        }
    }
    
    func onEdit() {
        flowController.toEdit(itemID)
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
            password = PasswordRenderer(password: passwordDecrypted).makeColorizedAttributedString()
        }
    }
    
    func onCopyUsername() {
        if let username {
            interactor.copy(username)
            toastPresenter.presentUsernameCopied()
        } else {
            toastPresenter.present(
                T.passwordErrorCopyUsername,
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
                T.passwordErrorCopyPassword,
                style: .failure
            )
        }
    }
    
    func onOpenURI(_ url: URL) {
        flowController.toOpenURI(url)
    }
    
    func onCopyURI(_ url: URL) {
        interactor.copy(url.absoluteString)
    }
    
    func uriKey(at index: Int) -> LocalizedStringKey {
        uri.count == 1 ? T.loginUriLabel.localizedKey : T.loginUriLabelLld(index+1).localizedKey
    }
}

private extension ViewPasswordPresenter {
    func reload() {
        guard let passwordData = interactor.fetchPassword(for: itemID) else {
            flowController.close()
            return
        }
        
        if passwordData.password != nil, let password = interactor.decryptPassword(for: itemID) {
            isPasswordAvailable = true
            passwordDecrypted = password
            self.password = AttributedString(passwordPlaceholder)
        } else {
            isPasswordAvailable = false
            passwordDecrypted = nil
            self.password = nil
        }
        
        if let username = passwordData.username {
            isUsernameAvailable = true
            self.username = username
        } else {
            isUsernameAvailable = false
            self.username = nil
        }
        
        name = passwordData.name ?? ""
        notes = passwordData.notes
        protectionLevel = passwordData.protectionLevel
        uri = passwordData.uris?.map {
            ViewPasswordURIPosition(
                id: .init(),
                uri: $0.uri,
                uriNormalized: interactor.normalizedURL(for: $0),
                match: $0.match
            )
        } ?? []
        icon = passwordData.iconType
        
        switch passwordData.iconType {
        case .label(labelTitle: let title, labelColor: let color):
            iconContent = .label(title, color: color)
            
        case .customIcon(let url):
            iconContent = defaultIconContent
            fetchIcon(from: url, name: passwordData.name ?? "")
            
        case .domainIcon:
            iconContent = defaultIconContent
            
            if let url = passwordData.iconType.iconURL {
                fetchIcon(from: url, name: passwordData.name ?? "")
            }
        }
        createdAt = dateFormatter.string(from: passwordData.creationDate)
        modifiedAt = dateFormatter.string(from: passwordData.modificationDate)
        
        if let tagIds = passwordData.tagIds, tagIds.isEmpty == false {
            tags = interactor.fetchTags(for: tagIds).map(\.name).joined(separator: ", ")
        } else {
            tags = nil
        }
    }
    
    @objc
    func syncFinished(_ event: Notification) {
        guard let e = event.userInfo?[Notification.webDAVState] as? WebDAVState, e == .synced else {
            return
        }
        refreshState()
    }
    
    @objc
    func iCloudSyncFinished() {
        refreshState()
    }
    
    func refreshState() {
        DispatchQueue.main.async {
            self.reload()
        }
    }
    
    var defaultIconContent: IconContent {
        .label(Config.defaultIconLabel(forName: name), color: nil)
    }
}

struct ViewPasswordURIPosition: Hashable, Identifiable {
    let id: UUID
    var uri: String
    var uriNormalized: URL?
    var match: PasswordURI.Match
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
