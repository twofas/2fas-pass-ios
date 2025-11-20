// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

@Observable
final class LoginEditorFormPresenter: ItemEditorFormPresenter {
        
    override var name: String {
        get { super.name }
        set {
            let oldValue = name
            super.name = newValue
            if oldValue != newValue {
                updateIcon()
            }
        }
    }
    
    var username: String = ""
    var password: String = ""
    var notes: String = ""
    
    var uri: [URI] = [] {
        didSet {
            updateSelectedURIIndex(oldURIs: oldValue)
            updateURIState()
            
            if oldValue != uri {
                updateIcon()
            }
        }
    }
    
    var usernameChanged: Bool {
        guard let initialLoginItem else {
            return false
        }
        return username != (initialLoginItem.username ?? "")
    }

    var passwordChanged: Bool {
        guard let initialDecryptedPassword else {
            return false
        }
        return password != initialDecryptedPassword
    }

    var notesChanged: Bool {
        guard let initialLoginItem else {
            return false
        }
        return notes != (initialLoginItem.notes ?? "")
    }
    
    var showGeneratePassword = false
    var showMostUsed = false
    var onFocusField: ((LoginEditorFormView.Field?) -> Void)?
    
    var uriError: String?

    let maxURICount = Config.maxURICount
    var showAddURI = false

    var iconContent: IconContent = .placeholder
    var iconType: PasswordIconType = .domainIcon(nil)
    var selectedURIIconIndex: Int?

    private let initialDecryptedPassword: String? = nil
    
    private var initialLoginItem: LoginItemData? {
        initialData as? LoginItemData
    }
    
    private var fetchImageTask: Task<Void, Error>?

    init(interactor: ItemEditorModuleInteracting, flowController: ItemEditorFlowControlling, initialData: LoginItemData? = nil, changeRequest: LoginDataChangeRequest? = nil) {
        var changeRequest = changeRequest
        
        if let initialData {
            username = changeRequest?.username?.value ?? initialData.username ?? ""

            let decryptedPassword: String
            if initialData.password != nil {
                decryptedPassword = interactor.decryptPassword(in: initialData) ?? ""
            } else {
                decryptedPassword = ""
            }
            
            switch changeRequest?.password {
            case .generate:
                password = interactor.generatePassword()
            case .value(let passwordValue):
                password = passwordValue
            case nil:
                password = decryptedPassword
            }
            
            uri = (changeRequest?.uris ?? initialData.uris)?.map { URI(id: .init(), uri: $0.uri, match: $0.match) } ?? []
            notes = changeRequest?.notes ?? initialData.notes ?? ""
            
            iconType = initialData.iconType
                        
            if case .domainIcon(let domain) = initialData.iconType, let domain {
                selectedURIIconIndex = (changeRequest?.uris ?? initialData.uris)?.firstIndex(where: {
                    interactor.extractDomain(from: $0.uri) == domain
                })
            }
            
        } else {
            username = changeRequest?.username?.value ?? interactor.mostUsedUsernames().first ?? ""
            uri = (changeRequest?.uris ?? []).map { URI(id: .init(), uri: $0.uri, match: $0.match) }
            
            if let changeRequestPassword = changeRequest?.password?.value {
                password = changeRequestPassword
            } else {
                password = interactor.generatePassword()
            }
            
            if let initialURI = changeRequest?.uris?.first?.uri, let domain = interactor.extractDomain(from: initialURI) {
                if changeRequest?.name == nil {
                    changeRequest?.name = domain
                }
                selectedURIIconIndex = 0
            }
            iconType = .domainIcon(nil)
        }
        
        super.init(interactor: interactor, flowController: flowController, initialData: initialData, changeRequest: changeRequest)
        
        updateURIState()
        updateIcon()
    }

    func randomPassword() {
        password = interactor.generatePassword()
    }

    func mostUsedUsernamesForKeyboard() -> [String] {
        return Array(interactor.mostUsedUsernames().prefix(2))
    }

    func mostUsedUsernames() -> [String] {
        return interactor.mostUsedUsernames()
    }

    func uriChanged(id: UUID) -> Bool {
        guard let index = uri.firstIndex(where: { $0.id == id }) else {
            return false
        }
        guard let initialLoginItem else {
            return false
        }
        guard let passwordUris = initialLoginItem.uris, index < passwordUris.count else {
            return true
        }
        return uri[index].uri != passwordUris[index].uri || uri[index].match != passwordUris[index].match
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

    func onSelectMatch(_ uuid: UUID, match: PasswordURI.Match) {
        guard let index = uri.firstIndex(where: { $0.id == uuid }) else {
            return
        }
        var uriData = uri[index]
        uriData.match = match
        uri[index] = uriData
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
    }
    
    func cancelFetchIcon() {
        fetchImageTask?.cancel()
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
    
    func onSave() -> SaveItemResult {
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
            return .failure(.uriNormalizationFailed)
        }
        uriError = nil
        updateURIState()

        return interactor.saveLogin(
            name: name,
            username: username,
            password: password,
            notes: notes.nilIfEmpty,
            iconType: iconType,
            protectionLevel: protectionLevel,
            uris: checkedURIs.map { content in
                PasswordURI(uri: content.original, match: content.match)
            },
            tagIds: Array(selectedTags.map { $0.tagID })
        )
    }
    
    deinit {
        fetchImageTask?.cancel()
    }
    
    private func updateURIState() {
        showAddURI = uriError == nil &&
        uri.count == uri.compactMap({ content -> URL? in
            guard !content.uri.trim().isEmpty else {
                return nil
            }
            return URL(string: content.uri)
        }).count
    }

    private func updateIcon() {
        switch iconType {
        case .label(let title, let color):
            iconContent = .label(title, color: color)

        case .customIcon(let url):
            if iconType.iconURL != url || iconContent.isPlaceholder {
                iconType = .customIcon(url)
                iconContent = .loading

                fetchImageTask?.cancel()
                fetchImageTask = Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let imageData = try? await self.interactor.fetchIconImage(from: url), let image = UIImage(data: imageData) {
                        self.iconContent = .icon(image)
                    } else {
                        self.setFallbackIconContent(name: name)
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
                        guard let self else { return }
                        if let imageData = try? await self.interactor.fetchIconImage(from: url),
                            let image = UIImage(data: imageData) {
                            self.iconContent = .icon(image)
                        } else {
                            self.setFallbackIconContent(name: name)
                        }
                    }
                }
            } else {
                iconType = .domainIcon(nil)
                setFallbackIconContent(name: name)
            }
        }
    }

    private func setFallbackIconContent(name: String) {
        let title = Config.defaultIconLabel(forName: name)
        if title.isEmpty {
            iconContent = .placeholder
        } else {
            iconContent = .label(title, color: nil)
        }
    }

    private func updateSelectedURIIndex(oldURIs: [URI]) {
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
}
