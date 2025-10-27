// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV
import ZIPFoundation

public enum ExternalServiceImportError: Error {
    case wrongFormat
    case wrongFileSize
    case cantReadFile
}

public protocol ExternalServiceImportInteracting: AnyObject {
    
    func openFile(from url: URL) async throws(ExternalServiceImportError) -> Data

    func importService(
        _ service: ExternalService,
        content: Data
    ) async -> Result<[ItemData], ExternalServiceImportError>
}

final class ExternalServiceImportInteractor {
    private let mainRepository: MainRepository
    private let uriInteractor: URIInteracting
    
    init(mainRepository: MainRepository, uriInteractor: URIInteracting) {
        self.mainRepository = mainRepository
        self.uriInteractor = uriInteractor
    }
}

extension ExternalServiceImportInteractor: ExternalServiceImportInteracting {
    
    func openFile(from url: URL) async throws(ExternalServiceImportError) -> Data {
        guard let fileURL = mainRepository.copyFileToLocalIfNeeded(from: url) else {
            throw .cantReadFile
        }

        guard let fileSize = mainRepository.checkFileSize(for: fileURL) else {
            throw .wrongFileSize
        }
        
        guard fileSize < Config.maximumExternalImportFileSize else {
            throw .wrongFileSize
        }
        
        guard let data = await mainRepository.readFileData(from: fileURL) else {
            throw .cantReadFile
        }
        
        return data
    }
    
    func importService(
        _ service: ExternalService,
        content: Data
    ) async -> Result<[ItemData], ExternalServiceImportError> {
        switch service {
        case .onePassword:
            return await importOnePassword(content: content)
        case .bitWarden:
            return await importBitWarden(content: content)
        case .chrome:
            return await importChrome(content: content)
        case .dashlaneMobile:
            return await importDashlaneMobile(content: content)
        case .dashlaneDesktop:
            return await importDashlaneDesktop(content: content)
        case .lastPass:
            return await importLastPass(content: content)
        case .protonPass:
            return await importProtonPass(content: content)
        case .applePasswordsMobile:
            return await importApplePasswordsMobile(content: content)
        case .applePasswordsDesktop:
            return await importApplePasswordsDesktop(content: content)
        case .firefox:
            return await importFirefox(content: content)
        case .keePass:
            return await importKeePass(content: content)
        case .keePassXC:
            return await importKeePassXC(content: content)
        case .microsoftEdge:
            return await importMicrosoftEdge(content: content)
        case .enpass:
            return await importEnpass(content: content)
        }
    }
}

private extension ExternalServiceImportInteractor {
    func encryptPassword(_ string: String, for protectionLevel: ItemProtectionLevel) -> Data? {
        guard let key = mainRepository.getKey(isPassword: true, protectionLevel: protectionLevel),
              let passwordData = string.data(using: .utf8),
              let password = mainRepository.encrypt(passwordData, key: key) else {
            return nil
        }
        return password
    }

    var selectedVaultId: VaultID? {
        mainRepository.selectedVault?.vaultID
    }
}

private extension ExternalServiceImportInteractor {
    func importOnePassword(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel

        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["Title", "Url", "Username", "Password", "Notes"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["Title"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["Url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["Username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["Password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["Notes"]?.nilIfEmpty

                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: .importPasswordPlaceholder,
                            modificationDate: .importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                            uris: uris
                        )
                    ))
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }

        return .success(items)
    }
    
    func importBitWarden(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let parsedJSON = try? mainRepository.jsonDecoder.decode(BitWarden.self, from: content),
              parsedJSON.encrypted == false
        else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel

        parsedJSON.items?.forEach { item in
            let name = item.name.formattedName
            let notes = item.notes
            let username = item.login?.username
            let password: Data? = {
                if let passwordString = item.login?.password?.nilIfEmpty,
                   let password = encryptPassword(passwordString, for: protectionLevel) {
                    return password
                }
                return nil
            }()
            let uris: [PasswordURI]? = { () -> [PasswordURI]? in
                guard let list = item.login?.uris else {
                    return nil
                }
                let urisList: [PasswordURI] = list.compactMap { uriEntry in
                    guard let uri = uriEntry.uri, !uri.isEmpty else {
                        return nil
                    }
                    return PasswordURI(uri: uri, match: uriEntry.matchValue)
                }
                guard !urisList.isEmpty else {
                    return nil
                }
                return urisList
            }()

            items.append(
                .login(.init(
                    id: .init(),
                    vaultId: vaultID,
                    metadata: .init(
                        creationDate: Date.importPasswordPlaceholder,
                        modificationDate: Date.importPasswordPlaceholder,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: nil
                    ),
                    name: name,
                    content: .init(
                        name: name,
                        username: username,
                        password: password,
                        notes: notes,
                        iconType: makeIconType(uri: uris?.first?.uri),
                        uris: uris
                    )
                ))
            )
        }

        return .success(items)
    }
    
    func importChrome(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["name", "url", "username", "password", "note"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["name"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["note"]?.nilIfEmpty
                
                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                            uris: uris
                        )
                    ))
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }
        
        return .success(items)
    }
    
    func importDashlaneMobile(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["username", "title", "password", "note", "url"]) else {
                return .failure(.wrongFormat)
            }
            
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["title"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["note"]?.nilIfEmpty
                
                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                            uris: uris
                        )
                    ))
                )
            }
            
            return .success(items)
            
        } catch {
            return .failure(.wrongFormat)
        }
    }
    
    func importDashlaneDesktop(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let archive = try? Archive(data: content, accessMode: .read, pathEncoding: .utf8) else {
            return .failure(.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        if let entry = archive.first(where: { $0.path.hasSuffix("credentials.csv")}) {
            do {
                var fileData = Data()
                _ = try archive.extract(entry) { data in
                    fileData.append(data)
                }
                
                guard let csvString = String(data: fileData, encoding: .utf8) else {
                    return .failure(.wrongFormat)
                }
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.validateHeader(["username", "title", "password", "note", "url"]) else {
                    return .failure(.wrongFormat)
                }
                
                try csv.enumerateAsDict { [weak self] dict in
                    let name = dict["title"].formattedName
                    let uris: [PasswordURI]? = {
                        guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                        let uri = PasswordURI(uri: urlString, match: .domain)
                        return [uri]
                    }()
                    let username = dict["username"]?.nilIfEmpty
                    let password: Data? = {
                        if let passwordString = dict["password"]?.nilIfEmpty,
                           let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                            return password
                        }
                        return nil
                    }()
                    let notes = dict["note"]?.nilIfEmpty
                    
                    items.append(
                        .login(.init(
                            id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                                creationDate: Date.importPasswordPlaceholder,
                                modificationDate: Date.importPasswordPlaceholder,
                                protectionLevel: protectionLevel,
                                trashedStatus: .no,
                                tagIds: nil
                            ),
                            name: name,
                            content: .init(
                                name: name,
                                username: username,
                                password: password,
                                notes: notes,
                                iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                                uris: uris
                            )
                        ))
                    )
                }
                
            } catch {
                return .failure(.wrongFormat)
            }
        }
        
        if let entry = archive.first(where: { $0.path.hasSuffix("securenotes.csv")}) {
            do {
                var fileData = Data()
                _ = try archive.extract(entry) { data in
                    fileData.append(data)
                }
                
                guard let csvString = String(data: fileData, encoding: .utf8) else {
                    return .failure(.wrongFormat)
                }
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.validateHeader(["title", "note"]) else {
                    return .failure(.wrongFormat)
                }
                
                try csv.enumerateAsDict { dict in
                    let name = dict["title"].formattedName
                    let notes = dict["note"]?.nilIfEmpty
                    
                    items.append(
                        .login(.init(
                            id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                                creationDate: Date.importPasswordPlaceholder,
                                modificationDate: Date.importPasswordPlaceholder,
                                protectionLevel: protectionLevel,
                                trashedStatus: .no,
                                tagIds: nil
                            ),
                            name: name,
                            content: .init(
                                name: name,
                                username: nil,
                                password: nil,
                                notes: notes,
                                iconType: .default,
                                uris: nil
                            )
                        ))
                    )
                }
            } catch {
                return .failure(.wrongFormat)
            }
        }
        
        return .success(items)
    }
    
    func importLastPass(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["name", "url", "username", "password", "extra"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["name"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["extra"]?.nilIfEmpty
                
                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                            uris: uris
                        )
                    ))
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }
        
        return .success(items)
    }
    
    func importProtonPass(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["name", "url", "username", "password", "note"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["name"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["note"]?.nilIfEmpty
                
                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                            uris: uris
                        )
                    ))
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }
        
        return .success(items)
    }
    
    func importApplePasswordsMobile(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let archive = try? Archive(data: content, accessMode: .read, pathEncoding: .utf8) else {
            return .failure(.wrongFormat)
        }
        
        guard let passwordsCSVFile = archive.first(where: { $0.path.hasSuffix("csv") }) else {
            return .failure(.wrongFormat)
        }
                
        do {
            var fileData = Data()
            _ = try archive.extract(passwordsCSVFile) { data in
                fileData.append(data)
            }
            guard let csvString = String(data: fileData, encoding: .utf8) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            return await importApplePasswords(csvContent: csvString)
        } catch {
            return .failure(.wrongFormat)
        }
    }
    
    func importApplePasswordsDesktop(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        return await importApplePasswords(csvContent: csvString)
    }
    
    func importFirefox(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["url", "username", "password", "httpRealm", "formActionOrigin", "guid", "timeCreated", "timeLastUsed", "timePasswordChanged"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            
            var offset = 0
            try csv.enumerateAsDict { [weak self] dict in
                defer {
                    offset += 1
                }
                guard offset > 0 else { // ignore first line with firefox accont configuration
                    return
                }
                
                let name = dict["url"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let timeCreated = dict["timeCreated"]?.nilIfEmpty as? String
                let timePasswordChanged = dict["timePasswordChanged"]?.nilIfEmpty as? String

                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: timeCreated.map { Int($0) }?.map { Date(exportTimestamp: $0) } ?? Date.importPasswordPlaceholder,
                            modificationDate: timePasswordChanged.map { Int($0) }?.map { Date(exportTimestamp: $0) } ?? Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: nil,
                            iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                            uris: uris
                        )
                    ))
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }
        
        return .success(items)
    }
    
    private func importApplePasswords(csvContent: String) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvContent, delimiter: .comma)
            guard csv.validateHeader(["Title", "URL", "Username", "Password", "Notes"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let username = dict["Username"]?.nilIfEmpty
                let name: String? = {
                    let name = dict["Title"].formattedName
                    if let name, let username {
                        let suffixToRemove = " (\(username))"
                        if name.hasSuffix(suffixToRemove){
                            return String(name.dropLast(suffixToRemove.count))
                        }
                    }
                    return name
                }()
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["URL"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let password: Data? = {
                    if let passwordString = dict["Password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["Notes"]?.nilIfEmpty
                
                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                            uris: uris
                        )
                    ))
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }
        
        return .success(items)
    }
    
    func importKeePass(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var passwords: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["Account", "Login Name", "Password", "Web Site", "Comments"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["Account"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["Web Site"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["Login Name"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["Password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["Comments"]?.nilIfEmpty

                passwords.append(
                    .login(
                        .init(
                            id: .init(),
                            vaultId: vaultID,
                            metadata: .init(
                                creationDate: Date.importPasswordPlaceholder,
                                modificationDate: Date.importPasswordPlaceholder,
                                protectionLevel: protectionLevel,
                                trashedStatus: .no,
                                tagIds: nil
                            ),
                            name: name,
                            content: .init(
                                name: name,
                                username: username,
                                password: password,
                                notes: notes,
                                iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                                uris: uris
                            )
                        )
                    )
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }
        
        return .success(passwords)
    }
    
    func importKeePassXC(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var passwords: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["Title", "Username", "Password", "URL", "Notes", "Last Modified", "Created"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["Title"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["URL"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["Username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["Password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["Notes"]?.nilIfEmpty

                let dateFormatter = ISO8601DateFormatter()
                let creationDate = dict["Created"]?.nilIfEmpty.flatMap { dateFormatter.date(from: $0) }
                let modificationDate = dict["Last Modified"]?.nilIfEmpty.flatMap { dateFormatter.date(from: $0) }
                
                passwords.append(
                    .login(
                        .init(
                            id: .init(),
                            vaultId: vaultID,
                            metadata: .init(
                                creationDate: creationDate ?? Date.importPasswordPlaceholder,
                                modificationDate: modificationDate ?? Date.importPasswordPlaceholder,
                                protectionLevel: protectionLevel,
                                trashedStatus: .no,
                                tagIds: nil
                            ),
                            name: name,
                            content: .init(
                                name: name,
                                username: username,
                                password: password,
                                notes: notes,
                                iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                                uris: uris
                            )
                        )
                    )
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }
        
        return .success(passwords)
    }
    
    func importMicrosoftEdge(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let csvString = String(data: content, encoding: .utf8) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var passwords: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel

        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.validateHeader(["name", "url", "username", "password", "note"]) else {
                return .failure(ExternalServiceImportError.wrongFormat)
            }
            try csv.enumerateAsDict { [weak self] dict in
                let name = dict["name"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["password"]?.nilIfEmpty,
                       let password = self?.encryptPassword(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let notes = dict["note"]?.nilIfEmpty

                passwords.append(
                    .login(
                        .init(
                            id: .init(),
                            vaultId: vaultID,
                            metadata: .init(
                                creationDate: Date.importPasswordPlaceholder,
                                modificationDate: Date.importPasswordPlaceholder,
                                protectionLevel: protectionLevel,
                                trashedStatus: .no,
                                tagIds: nil
                            ),
                            name: name,
                            content: .init(
                                name: name,
                                username: username,
                                password: password,
                                notes: notes,
                                iconType: self?.makeIconType(uri: uris?.first?.uri) ?? .default,
                                uris: uris
                            )
                        )
                    )
                )
            }
        } catch {
            return .failure(.wrongFormat)
        }

        return .success(passwords)
    }

    func importEnpass(content: Data) async -> Result<[ItemData], ExternalServiceImportError> {
        guard let parsedJSON = try? mainRepository.jsonDecoder.decode(Enpass.self, from: content) else {
            return .failure(ExternalServiceImportError.wrongFormat)
        }
        guard let vaultID = selectedVaultId else {
            return .failure(.wrongFormat)
        }
        var items: [ItemData] = []
        let protectionLevel = mainRepository.currentDefaultProtectionLevel

        parsedJSON.items?.forEach { item in
            guard item.trashed != 1 else { return }

            let name = item.title.formattedName
            let notes = item.note?.nilIfEmpty

            var username: String?
            var password: Data?
            var urlString: String?

            item.fields?.forEach { field in
                guard field.deleted != 1 else { return }

                switch field.type {
                case "username":
                    username = field.value?.nilIfEmpty
                case "password":
                    if let passwordString = field.value?.nilIfEmpty {
                        password = encryptPassword(passwordString, for: protectionLevel)
                    }
                case "url":
                    urlString = field.value?.nilIfEmpty
                default:
                    break
                }
            }

            let uris: [PasswordURI]? = {
                guard let urlString else { return nil }
                let uri = PasswordURI(uri: urlString, match: .domain)
                return [uri]
            }()

            items.append(
                .login(.init(
                    id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                        creationDate: Date.importPasswordPlaceholder,
                        modificationDate: Date.importPasswordPlaceholder,
                        protectionLevel: protectionLevel,
                        trashedStatus: .no,
                        tagIds: nil
                    ),
                    name: name,
                    content: .init(
                        name: name,
                        username: username,
                        password: password,
                        notes: notes,
                        iconType: makeIconType(uri: uris?.first?.uri),
                        uris: uris
                    )
                ))
            )
        }

        return .success(items)
    }

    private func makeIconType(uri: String?) -> PasswordIconType {
        guard let uri else {
            return .createDefault(domain: nil)
        }
        
        let domain = uriInteractor.extractDomain(from: uri)
        return .createDefault(domain: domain)
    }
}

private extension CSV {
    func validateHeader(_ headerRow: [String]) -> Bool {
        headerRow.reduce(into: true) { result, headerEntry in
            result = result && self.header.contains(where: { $0 == headerEntry })
        }
    }
}

private struct BitWarden: Decodable {
    struct Item: Decodable {
        struct Login: Decodable {
            struct URI: Decodable {
                let uri: String?
                let match: Int?

                var matchValue: PasswordURI.Match {
                    switch match {
                    case 0: .domain
                    case 1: .host
                    case 2: .startsWith
                    case 3: .exact
                    default: .domain
                    }
                }
            }

            let username: String?
            let password: String?
            let uris: [URI]?
        }

        let name: String?
        let notes: String?
        let login: Login?
    }
    let encrypted: Bool
    let items: [Item]?
}

private struct Enpass: Decodable {
    struct Item: Decodable {
        struct Field: Decodable {
            let label: String?
            let type: String?
            let value: String?
            let sensitive: Int?
            let deleted: Int?
        }

        let title: String?
        let note: String?
        let category: String?
        let fields: [Field]?
        let trashed: Int?
    }

    let items: [Item]?
}
