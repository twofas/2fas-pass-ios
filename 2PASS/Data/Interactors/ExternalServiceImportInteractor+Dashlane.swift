// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV
import ZIPFoundation

extension ExternalServiceImportInteractor {

    struct DashlaneImporter {
        let context: ImportContext

        func importMobileCSV(_ files: [Data]) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            let protectionLevel = context.currentProtectionLevel
            let tagResolver = TagResolver(vaultID: vaultID)

            // Process each CSV file and detect type based on headers
            for data in files {
                guard let csvString = String(data: data, encoding: .utf8) else { continue }

                do {
                    let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                    let csvType = detectCSVType(from: csv.header)

                    switch csvType {
                    case .credentials:
                        let credentialItems = try importCredentialsFromData(
                            data,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            resolveTagIds: tagResolver.resolve
                        )
                        items.append(contentsOf: credentialItems)
                    case .secureNotes:
                        let noteItems = try importSecureNotesFromData(
                            data,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            resolveTagIds: tagResolver.resolve
                        )
                        items.append(contentsOf: noteItems)
                    case .payments:
                        let result = try importPaymentsFromData(data, vaultID: vaultID, protectionLevel: protectionLevel)
                        items.append(contentsOf: result.items)
                        itemsConvertedToSecureNotes += result.convertedCount
                    case .ids:
                        let idItems = try importIDsFromData(data, vaultID: vaultID, protectionLevel: protectionLevel)
                        items.append(contentsOf: idItems)
                        itemsConvertedToSecureNotes += idItems.count
                    case .personalInfo:
                        let personalItems = try importPersonalInfoFromData(data, vaultID: vaultID, protectionLevel: protectionLevel)
                        items.append(contentsOf: personalItems)
                        itemsConvertedToSecureNotes += personalItems.count
                    case .wifi:
                        let wifiItems = try importWiFiFromData(data, vaultID: vaultID, protectionLevel: protectionLevel)
                        items.append(contentsOf: wifiItems)
                        itemsConvertedToSecureNotes += wifiItems.count
                    case .unknown:
                        // Skip unknown CSV types
                        continue
                    }
                } catch {
                    // Skip files that fail to parse
                    continue
                }
            }

            return ExternalServiceImportResult(
                items: items,
                tags: tagResolver.tags,
                itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
            )
        }

        func importDesktopZIP(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let archive = try? Archive(data: content, accessMode: .read, pathEncoding: .utf8) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            let protectionLevel = context.currentProtectionLevel
            let tagResolver = TagResolver(vaultID: vaultID)

            // Import credentials
            if let entry = archive.first(where: { $0.path.hasSuffix("credentials.csv") }) {
                let data = try extractData(from: archive, entry: entry)
                let credentialItems = try importCredentialsFromData(
                    data,
                    vaultID: vaultID,
                    protectionLevel: protectionLevel,
                    resolveTagIds: tagResolver.resolve
                )
                items.append(contentsOf: credentialItems)
            }

            // Import secure notes
            if let entry = archive.first(where: { $0.path.hasSuffix("securenotes.csv") }) {
                let data = try extractData(from: archive, entry: entry)
                let noteItems = try importSecureNotesFromData(
                    data,
                    vaultID: vaultID,
                    protectionLevel: protectionLevel,
                    resolveTagIds: tagResolver.resolve
                )
                items.append(contentsOf: noteItems)
            }

            // Import payment cards and bank accounts
            if let entry = archive.first(where: { $0.path.hasSuffix("payments.csv") }) {
                let data = try extractData(from: archive, entry: entry)
                let result = try importPaymentsFromData(data, vaultID: vaultID, protectionLevel: protectionLevel)
                items.append(contentsOf: result.items)
                itemsConvertedToSecureNotes += result.convertedCount
            }

            // Import IDs (as secure notes)
            if let entry = archive.first(where: { $0.path.hasSuffix("ids.csv") }) {
                let data = try extractData(from: archive, entry: entry)
                let idItems = try importIDsFromData(data, vaultID: vaultID, protectionLevel: protectionLevel)
                items.append(contentsOf: idItems)
                itemsConvertedToSecureNotes += idItems.count
            }

            // Import personal info (as secure notes)
            if let entry = archive.first(where: { $0.path.hasSuffix("personalInfo.csv") }) {
                let data = try extractData(from: archive, entry: entry)
                let personalItems = try importPersonalInfoFromData(data, vaultID: vaultID, protectionLevel: protectionLevel)
                items.append(contentsOf: personalItems)
                itemsConvertedToSecureNotes += personalItems.count
            }

            return ExternalServiceImportResult(
                items: items,
                tags: tagResolver.tags,
                itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
            )
        }
    }
}

private extension ExternalServiceImportInteractor.DashlaneImporter {

    func importCredentialsFromData(
        _ data: Data,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        resolveTagIds: @escaping (String?) -> [ItemTagID]?
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw ExternalServiceImportError.wrongFormat
            }
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["username", "title", "password", "note", "url"]) else {
                throw ExternalServiceImportError.wrongFormat
            }

            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let name = dict["title"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["url"]?.nonBlankTrimmedOrNil else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["username"]?.nonBlankTrimmedOrNil
                    ?? dict["username2"]?.nonBlankTrimmedOrNil
                    ?? dict["username3"]?.nonBlankTrimmedOrNil
                let password: Data? = {
                    if let passwordString = dict["password"]?.nonBlankTrimmedOrNil,
                       let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()

                let note = dict["note"]?.nonBlankTrimmedOrNil
                let tagIds = resolveTagIds(dict["category"])

                var excludingKeys: Set<String> = ["title", "url", "username", "password", "note", "category"]
                if dict["username"]?.nonBlankTrimmedOrNil == nil {
                    excludingKeys.insert("username2")
                }
                if dict["username2"]?.nonBlankTrimmedOrNil == nil {
                    excludingKeys.insert("username3")
                }
                
                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: excludingKeys,
                    keyMap: [
                        "username2": "Username",
                        "username3": "Alternate username"
                    ]
                )
                let notes = context.mergeNote(note, with: additionalInfo)

                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: tagIds
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: context.makeIconType(uri: uris?.first?.uri),
                            uris: uris
                        )
                    ))
                )
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }

        return items
    }

    func importSecureNotesFromData(
        _ data: Data,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        resolveTagIds: @escaping (String?) -> [ItemTagID]?
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw ExternalServiceImportError.wrongFormat
            }
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["title", "note"]) else {
                throw ExternalServiceImportError.wrongFormat
            }

            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let name = dict["title"].formattedName
                let text: Data? = {
                    if let noteString = dict["note"]?.nonBlankTrimmedOrNil,
                       let encrypted = context.encryptSecureField(noteString, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()

                let tagIds = resolveTagIds(dict["category"])
                let additionalInfo = context.formatDictionary(dict, excludingKeys: ["title", "note", "category"])

                items.append(
                    .secureNote(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: tagIds
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            text: text,
                            additionalInfo: additionalInfo
                        )
                    ))
                )
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }

        return items
    }

    func importPaymentsFromData(
        _ data: Data,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) throws(ExternalServiceImportError) -> (items: [ItemData], convertedCount: Int) {
        var items: [ItemData] = []
        var convertedCount = 0

        do {
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw ExternalServiceImportError.wrongFormat
            }
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["type", "name", "account_holder", "note"]) else {
                throw ExternalServiceImportError.wrongFormat
            }

            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let paymentType = dict["type"]?.nonBlankTrimmedOrNil ?? "payment_card"

                // All payment types (including payment_card) -> secure note
                let typeName = formatTypeName(paymentType)
                let itemName = dict["name"]?.nonBlankTrimmedOrNil ?? dict["account_name"]?.nonBlankTrimmedOrNil
                let name: String = {
                    var output = ""
                    if let itemName {
                        output.append("\(itemName) ")
                    }
                    return output + "(\(typeName))"
                }()

                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: ["type", "name", "account_name", "note"]
                )
                let noteText = context.mergeNote(additionalInfo, with: dict["note"]?.nonBlankTrimmedOrNil)

                let text: Data? = {
                    if let note = noteText,
                       let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()

                items.append(
                    .secureNote(.init(
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
                            text: text,
                            additionalInfo: nil
                        )
                    ))
                )
                convertedCount += 1
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }

        return (items: items, convertedCount: convertedCount)
    }

    func importIDsFromData(
        _ data: Data,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw ExternalServiceImportError.wrongFormat
            }
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["type", "number", "name"]) else {
                throw ExternalServiceImportError.wrongFormat
            }

            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let idType = dict["type"]?.nonBlankTrimmedOrNil ?? "id"
                let typeName = formatTypeName(idType)
                let idName = dict["name"]?.nonBlankTrimmedOrNil
                let name: String = {
                    var output = ""
                    if let idName {
                        output.append("\(idName) ")
                    }
                    return output + "(\(typeName))"
                }()

                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: ["type", "name"]
                )

                let text: Data? = {
                    if let info = additionalInfo,
                       let encrypted = context.encryptSecureField(info, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()

                items.append(
                    .secureNote(.init(
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
                            text: text,
                            additionalInfo: nil
                        )
                    ))
                )
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }

        return items
    }

    func importPersonalInfoFromData(
        _ data: Data,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw ExternalServiceImportError.wrongFormat
            }
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["type"]) else {
                throw ExternalServiceImportError.wrongFormat
            }

            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let infoType = dict["type"]?.nonBlankTrimmedOrNil ?? "personal"
                let typeName = formatTypeName(infoType)

                let name: String? = {
                    let detectedName: () -> String? = {
                        switch infoType {
                        case "name":
                            [dict["first_name"], dict["middle_name"], dict["last_name"]]
                                .compactMap { $0?.nonBlankTrimmedOrNil }
                                .joined(separator: " ")
                                .nonBlankTrimmedOrNil
                        case "email":
                            dict["email"]?.nonBlankTrimmedOrNil
                        case "number":
                            dict["phone_number"]?.nonBlankTrimmedOrNil
                        case "website":
                            dict["url"]?.nonBlankTrimmedOrNil
                        default:
                            nil
                        }
                    }

                    let displayName: String? = dict["item_name"]?.nonBlankTrimmedOrNil ?? detectedName()

                    var output = ""
                    if let displayName, !displayName.isEmpty {
                        output.append("\(displayName) ")
                    }
                    return output + "(\(typeName))"
                }()

                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: ["type", "item_name"]
                )

                let text: Data? = {
                    if let info = additionalInfo,
                       let encrypted = context.encryptSecureField(info, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()

                items.append(
                    .secureNote(.init(
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
                            text: text,
                            additionalInfo: nil
                        )
                    ))
                )
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }

        return items
    }

    func importWiFiFromData(
        _ data: Data,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            guard let csvString = String(data: data, encoding: .utf8) else {
                throw ExternalServiceImportError.wrongFormat
            }
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["ssid"]) else {
                throw ExternalServiceImportError.wrongFormat
            }

            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let ssid = dict["ssid"]?.nonBlankTrimmedOrNil
                let wifiName = dict["name"]?.nonBlankTrimmedOrNil
                let name: String = {
                    var output = ""
                    if let displayName = wifiName ?? ssid {
                        output.append("\(displayName) ")
                    }
                    return output + "(WiFi)"
                }()

                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: ["name", "note"]
                )
                let noteText = context.mergeNote(additionalInfo, with: dict["note"]?.nonBlankTrimmedOrNil)

                let text: Data? = {
                    if let note = noteText,
                       let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()

                items.append(
                    .secureNote(.init(
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
                            text: text,
                            additionalInfo: nil
                        )
                    ))
                )
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }

        return items
    }
}

private extension ExternalServiceImportInteractor.DashlaneImporter {

    enum DashlaneCSVType {
        case credentials
        case secureNotes
        case payments
        case ids
        case personalInfo
        case wifi
        case unknown
    }
    
    func detectCSVType(from header: [String]) -> DashlaneCSVType {
        if header.containsAll(["username", "title", "password", "url"]) {
            return .credentials
        } else if header.containsAll(["title", "note"]) && !header.contains("password") {
            return .secureNotes
        } else if header.containsAll(["type", "account_holder"]) {
            return .payments
        } else if header.containsAll(["type", "number", "name"]) && header.contains("issue_date") {
            return .ids
        } else if header.containsAll(["type"]) && (header.contains("first_name") || header.contains("email") || header.contains("phone_number") || header.contains("address")) {
            return .personalInfo
        } else if header.containsAll(["ssid"]) {
            return .wifi
        }
        return .unknown
    }

    func extractData(from archive: Archive, entry: Entry) throws(ExternalServiceImportError) -> Data {
        do {
            var fileData = Data()
            _ = try archive.extract(entry) { data in
                fileData.append(data)
            }
            return fileData
        } catch {
            throw .wrongFormat
        }
    }
    
    func formatTypeName(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: "([a-z])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .capitalizedFirstLetter
    }
}

private extension ExternalServiceImportInteractor.DashlaneImporter {

    final class TagResolver {
        private let vaultID: VaultID
        private var categoryToTagId: [String: ItemTagID] = [:]
        private(set) var tags: [ItemTagData] = []

        init(vaultID: VaultID) {
            self.vaultID = vaultID
        }

        func resolve(for category: String?) -> [ItemTagID]? {
            guard let category = category?.nonBlankTrimmedOrNil else { return nil }
            if let existingTagId = categoryToTagId[category] {
                return [existingTagId]
            }
            let newTagId = ItemTagID()
            categoryToTagId[category] = newTagId
            tags.append(ItemTagData(
                tagID: newTagId,
                vaultID: vaultID,
                name: category,
                color: .gray,
                position: tags.count,
                modificationDate: Date()
            ))
            return [newTagId]
        }
    }
}
