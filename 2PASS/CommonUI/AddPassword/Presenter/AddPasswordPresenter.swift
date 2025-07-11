// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftUI
import Data

@Observable
final class AddPasswordPresenter {
    var saveEnabled: ((Bool) -> Void)?
    
    let maxURICount = Config.maxURICount
    
    var name = "" {
        didSet {
            if oldValue != name {
                updateIcon()
            }
            
            updateSaveState()
        }
    }
    var username = "" {
        didSet {
            updateSaveState()
        }
    }
    var password = "" {
        didSet {
            updateSaveState()
        }
    }
    var uri: [URI] = [] {
        didSet {
            updateSelectedURIIndex(oldURIs: oldValue)
            updateSaveState()
            updateURIState()
            
            if oldValue != uri {
                updateIcon()
            }
        }
    }
    var notes: String = "" {
        didSet {
            updateSaveState()
        }
    }
    var uriError: String?
    
    var protectionLevel: ItemProtectionLevel = .normal{
        didSet {
            updateSaveState()
        }
    }
    
    var showUsernameSheetIcon: Bool {
        interactor.hasPasswords
    }
    
    var nameChanged: Bool {
        guard let initialPasswordData else {
            return false
        }
        return name != (initialPasswordData.name ?? "")
    }
    
    var usernameChanged: Bool {
        guard let initialPasswordData else {
            return false
        }
        return username != (initialPasswordData.username ?? "")
    }
    
    var passwordChanged: Bool {
        guard let initialDecryptedPassword else {
            return false
        }
        return password != initialDecryptedPassword
    }
    
    var protectionLevelChanged: Bool {
        guard let initialPasswordData else {
            return false
        }
        return protectionLevel != initialPasswordData.protectionLevel
    }
    
    var notesChanged: Bool {
        guard let initialPasswordData else {
            return false
        }
        return notes != (initialPasswordData.notes ?? "")
    }
    
    func uriChanged(id: UUID) -> Bool {
        guard let index = uri.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard let initialPasswordData else {
            return false
        }
        guard let passwordUris = initialPasswordData.uris, index < passwordUris.count else {
            return true
        }
        return uri[index].uri != passwordUris[index].uri || uri[index].match != passwordUris[index].match
    }
    
    private(set) var iconType: PasswordIconType
    private(set) var iconContent: IconContent = .placeholder
    private(set) var selectedURIIconIndex: Int?
    
    var cantSave = false
    var showAddURI = false

    private(set) var isEdit: Bool
    
    var passwordWasEdited = false
    var passwordWasDeleted = false
    
    private var firstAppear = true
    
    private var fetchImageTask: Task<Void, Error>?
    
    private let flowController: AddPasswordFlowControlling
    private let interactor: AddPasswordModuleInteracting
    private let notificationCenter: NotificationCenter
    private let initialPasswordData: PasswordData?
    private let initialDecryptedPassword: String?
    
    init(flowController: AddPasswordFlowControlling, interactor: AddPasswordModuleInteracting) {
        self.flowController = flowController
        self.interactor = interactor
        self.notificationCenter = .default
        
        if let passwordData = interactor.getEditPassword() {
            initialPasswordData = passwordData
            
            let decryptedPassword: String
            if passwordData.password != nil {
                decryptedPassword = interactor.getDecryptedPassword() ?? ""
            } else {
                decryptedPassword = ""
            }
            initialDecryptedPassword = decryptedPassword
            name = interactor.changeRequest?.name ?? passwordData.name ?? ""
            username = interactor.changeRequest?.username ?? passwordData.username ?? ""
            
            switch interactor.changeRequest?.password {
            case .generateNewPassword:
                password = interactor.generatePassword()
            case .value(let passwordValue):
                password = passwordValue
            case nil:
                password = decryptedPassword
            }
            
            notes = interactor.changeRequest?.notes ?? passwordData.notes ?? ""
            uri = (interactor.changeRequest?.uris ?? passwordData.uris)?.map { URI(id: .init(), uri: $0.uri, match: $0.match) } ?? []
            protectionLevel = interactor.changeRequest?.protectionLevel ?? passwordData.protectionLevel
            iconType = passwordData.iconType
            
            if case .domainIcon(let domain) = passwordData.iconType, let domain {
                selectedURIIconIndex = passwordData.uris?.firstIndex(where: {
                    interactor.extractDomain(from: $0.uri) == domain
                })
            }
                
            isEdit = true
            updateURIState()
            updateIcon()

            notificationCenter.addObserver(self, selector: #selector(syncFinished), name: .webDAVStateChange, object: nil)
            notificationCenter.addObserver(self, selector: #selector(iCloudSyncFinished), name: .cloudStateChanged, object: nil)
        } else {
            initialPasswordData = nil
            initialDecryptedPassword = nil
            
            if let initialURI = interactor.changeRequest?.uris?.first?.uri, let domain = interactor.extractDomain(from: initialURI) {
                name = interactor.changeRequest?.name ?? domain
                selectedURIIconIndex = 0
            } else {
                name = interactor.changeRequest?.name ?? ""
            }
            username = interactor.changeRequest?.username ?? interactor.mostUsedUsernames().first ?? ""
            protectionLevel = interactor.changeRequest?.protectionLevel ?? interactor.currentDefaultProtectionLevel
            uri = (interactor.changeRequest?.uris ?? []).map { URI(id: .init(), uri: $0.uri, match: $0.match) }
            isEdit = false
            iconType = .domainIcon(nil)
            
            if let changeRequestPassword = interactor.changeRequest?.password?.value {
                password = changeRequestPassword
            } else {
                randomPassword()
            }
            
            updateURIState()
            updateIcon()
        }
    }
    
    func onRemoveURI(with id: UUID) {
        uri.removeAll(where: { $0.id == id })
    }
    
    func onRemoveURI(atOffsets offsets: IndexSet) {
        uri.remove(atOffsets: offsets)
    }
    
    func onAddURI() {
        uri.append(.empty())
    }
    
    func onClose() {
        flowController.close(with: .failure(.userCancelled))
    }
    
    func onChangeProtectionLevel() {
        flowController.toChangeProtectionLevel(current: protectionLevel)
    }
    
    func handleChangeProtectionLevel(_ value: ItemProtectionLevel) {
        protectionLevel = value
    }
    
    func handleIconChange(_ value: PasswordIconType) {
        iconType = value
        
        switch iconType {
        case .domainIcon(let domain):
            selectedURIIconIndex = uri.firstIndex(where: {
                interactor.extractDomain(from: $0.uri) == domain
            })
        default:
            selectedURIIconIndex = nil
        }
        
        iconContent = .placeholder
        updateIcon()
        updateSaveState()
    }
    
    func onAppear() {
        guard firstAppear else {
            return
        }
        updateSaveState()
        firstAppear = false
    }
    
    func onDisappear() {
        fetchImageTask?.cancel()
        fetchImageTask = nil
    }
    
    func onSave() {
        var incorrectURI: [String] = []
        
        let checkedURIs: [(original: String, match: PasswordURI.Match)] = uri
            .enumerated()
            .compactMap { index, content in
                guard !content.uri.trim().isEmpty else {
                    return nil
                }
                
                if let normalizedString = interactor.normalizeURLString(content.uri),
                   let _ = URL(string: normalizedString) {
                    return (original: content.uri, match: content.match)
                } else {
                    incorrectURI.append(String("\(index + 1)"))
                    return nil
                }
            }
        
        guard incorrectURI.isEmpty else {
            uriError = incorrectURI.joined(separator: ", ")
            updateURIState()
            return
        }
        uriError = nil
        updateURIState()
        
        let result = interactor.savePassword(
            name: name,
            username: username,
            password: password,
            notes: notes.nilIfEmpty,
            iconType: iconType,
            protectionLevel: protectionLevel,
            uris: checkedURIs.map { content in
                PasswordURI(uri: content.original, match: content.match)
            }
        )
        if result.isSuccess {
            flowController.close(with: result)
        } else {
            cantSave = true
        }
    }
    
    func onSelectMatch(_ uuid: UUID, match: PasswordURI.Match) {
        guard let index = uri.firstIndex(where: { $0.id == uuid }) else {
            return
        }
        var uriData = uri[index]
        uriData.match = match
        uri[index] = uriData
    }
    
    func mostUsedUsernamesForKeyboard() -> [String] {
        Array(mostUsedUsernames().prefix(2))
    }
    
    func mostUsedUsernames() -> [String] {
        interactor.mostUsedUsernames()
    }
    
    func onCustomizeIcon() {
        let uriDomains = uri.map { uri in
            interactor.extractDomain(from: uri.uri) ?? uri.uri
        }
                
        let uniqueDomains = uriDomains.reduce(into: [String]()) { result, domain in
            if !result.contains(domain) {
                result.append(domain)
            }
        }
    
        let data = CustomizeIconData(
            currentIconType: iconType,
            name: name,
            passwordName: name,
            uriDomains: uniqueDomains
        )
        flowController.toCustomizeIcon(data: data)
    }
    
    func randomPassword() {
        password = interactor.generatePassword()
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

private extension AddPasswordPresenter {
    
    func updateSelectedURIIndex(oldURIs: [URI]) {
        if let selectedURIIconIndex {
            let oldSelected = oldURIs[selectedURIIconIndex]
            if uri.contains(where: { $0.id == oldSelected.id }) == false, uri.isEmpty == false {
                self.selectedURIIconIndex = 0
            }
        }
        
        if uri.isEmpty {
            selectedURIIconIndex = nil
        } else if selectedURIIconIndex == nil {
            selectedURIIconIndex = 0
        }
    }
    
    func updateSaveState() {
        saveEnabled?(!name.isEmpty)
    }
    
    func updateIcon() {
        switch iconType {
        case .label(let title, let color):
            iconContent = .label(title, color: color)

        case .customIcon(let url):
            if iconType.iconURL != url || iconContent.isPlaceholder {
                iconType = .customIcon(url)
                iconContent = .loading
                
                fetchImageTask?.cancel()
                fetchImageTask = Task { @MainActor [weak self] in
                    if let imageData = try? await self?.interactor.fetchIconImage(from: url), let image = UIImage(data: imageData) {
                        self?.iconContent = .icon(image)
                    } else {
                        self?.setFallbackIconContent()
                    }
                }
            }
            
        case .domainIcon:
            let domain: String? = {
                if let selectedURIIconIndex {
                    let uri = uri[selectedURIIconIndex].uri
                    return interactor.extractDomain(from: uri)
                }
                return nil
            }()

            if let domain, let url = Config.iconURL(forDomain: domain) {
                if iconType.iconURL != url || iconContent.isPlaceholder {
                    iconType = .domainIcon(domain)
                    iconContent = .loading
                    
                    fetchImageTask?.cancel()
                    fetchImageTask = Task { @MainActor [weak self] in
                        if let imageData = try? await self?.interactor.fetchIconImage(from: url),
                            let image = UIImage(data: imageData) {
                            self?.iconContent = .icon(image)
                        } else {
                            self?.setFallbackIconContent()
                        }
                    }
                }
            } else {
                iconType = .domainIcon(nil)
                setFallbackIconContent()
            }
        }
    }
    
    private func setFallbackIconContent() {
        let title = Config.defaultIconLabel(forName: name)
        if title.isEmpty {
            iconContent = .placeholder
        } else {
            iconContent = .label(title, color: nil)
        }
    }
    
    func updateURIState() {
        showAddURI = uriError == nil &&
        uri.count == uri.compactMap({ content -> URL? in
            guard !content.uri.trim().isEmpty else {
                return nil
            }
            return URL(string: content.uri)
        }).count
    }
    
    @objc
    func syncFinished(_ event: Notification) {
        guard let e = event.userInfo?[Notification.webDAVState] as? WebDAVState, e == .synced else {
            return
        }
        checkCurrentPasswordState()
    }
    
    @objc
    func iCloudSyncFinished() {
        checkCurrentPasswordState()
    }
    
    func checkCurrentPasswordState() {
        DispatchQueue.main.async {
            switch self.interactor.checkCurrentPasswordState() {
            case .deleted: self.passwordWasDeleted = true
            case .edited: self.passwordWasEdited = true
            case .noChange: break
            }
        }
    }
}
