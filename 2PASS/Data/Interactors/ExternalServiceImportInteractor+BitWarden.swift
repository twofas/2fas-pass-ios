// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV

extension ExternalServiceImportInteractor {

    struct BitWardenImporter {
        let context: ImportContext

        private var decoder: JSONDecoder {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            if let parsedJSON = try? decoder.decode(BitWarden.self, from: content),
               parsedJSON.encrypted == false {
                return try await importJSON(parsedJSON)
            }

            if let csvString = String(data: content, encoding: .utf8) {
                return try await importCSV(csvString)
            }

            throw .wrongFormat
        }

        private func importJSON(_ parsedJSON: BitWarden) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            let protectionLevel = context.currentProtectionLevel

            // Create tags from folders
            let folderToTagId: [String: ItemTagID] = (parsedJSON.folders ?? []).reduce(into: [:]) { result, folder in
                result[folder.id] = ItemTagID()
            }

            let tags: [ItemTagData] = (parsedJSON.folders ?? []).enumerated().compactMap { index, folder -> ItemTagData? in
                guard let tagId = folderToTagId[folder.id] else { return nil }
                return ItemTagData(
                    tagID: tagId,
                    vaultID: vaultID,
                    name: folder.name,
                    color: .gray,
                    position: index,
                    modificationDate: Date()
                )
            }

            parsedJSON.items?.forEach { item in
                let tagIds: [ItemTagID]? = {
                    guard let folderId = item.folderId,
                          let tagId = folderToTagId[folderId] else { return nil }
                    return [tagId]
                }()

                switch item.type {
                case .login:
                    if let loginItem = parseLogin(
                        login: BitWarden.Login(item.login),
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(loginItem)
                    }
                case .secureNote:
                    if let noteItem = parseSecureNote(
                        secureNote: BitWarden.SecureNote(item.secureNote),
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(noteItem)
                    }
                case .card:
                    if let cardItem = parseCard(
                        card: BitWarden.Card(item.card),
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(cardItem)
                    }
                case .identity:
                    if let identityItem = parseAsSecureNote(
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        contentTypeName: "Identity",
                        data: item.identity,
                        tagIds: tagIds
                    ) {
                        items.append(identityItem)
                        itemsConvertedToSecureNotes += 1
                    }
                case .sshKey:
                    if let sshItem = parseAsSecureNote(
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        contentTypeName: "SSH Key",
                        data: item.sshKey,
                        tagIds: tagIds
                    ) {
                        items.append(sshItem)
                        itemsConvertedToSecureNotes += 1
                    }
                case .unknown:
                    break
                }
            }

            return ExternalServiceImportResult(items: items, tags: tags, itemsConvertedToSecureNotes: itemsConvertedToSecureNotes)
        }

        private func importCSV(_ csvString: String) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            let protectionLevel = context.currentProtectionLevel

            // Track unique folder names to create tags
            var folderToTagId: [String: ItemTagID] = [:]
            var tags: [ItemTagData] = []

            do {
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.header.containsAll([
                    "type", "name", "notes", "login_uri", "login_username", "login_password"
                ]) else {
                    throw ExternalServiceImportError.wrongFormat
                }

                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    // Handle folder -> tag mapping
                    let tagIds: [ItemTagID]? = {
                        guard let folderName = dict["folder"]?.nonBlankTrimmedOrNil else { return nil }
                        if let existingTagId = folderToTagId[folderName] {
                            return [existingTagId]
                        }
                        let newTagId = ItemTagID()
                        folderToTagId[folderName] = newTagId
                        tags.append(ItemTagData(
                            tagID: newTagId,
                            vaultID: vaultID,
                            name: folderName,
                            color: .gray,
                            position: tags.count,
                            modificationDate: Date()
                        ))
                        return [newTagId]
                    }()

                    let itemType = dict["type"] ?? "login"

                    switch itemType {
                    case "login":
                        if let loginItem = parseCSVLogin(dict: dict, vaultID: vaultID, protectionLevel: protectionLevel, tagIds: tagIds) {
                            items.append(loginItem)
                        }
                    case "note":
                        if let noteItem = parseCSVSecureNote(dict: dict, vaultID: vaultID, protectionLevel: protectionLevel, tagIds: tagIds) {
                            items.append(noteItem)
                        }
                    case "card":
                        if let cardItem = parseCSVCard(dict: dict, vaultID: vaultID, protectionLevel: protectionLevel, tagIds: tagIds) {
                            items.append(cardItem)
                        }
                    default:
                        break
                    }
                }
            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }

            return ExternalServiceImportResult(items: items, tags: tags)
        }
    }
}

// MARK: - CSV Parsing

private extension ExternalServiceImportInteractor.BitWardenImporter {

    func parseCSVLogin(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"]?.nonBlankTrimmedOrNil
        let notes = dict["notes"]?.nonBlankTrimmedOrNil
        let username = dict["login_username"]?.nonBlankTrimmedOrNil
        let password: Data? = {
            if let passwordString = dict["login_password"]?.nonBlankOrNil,
               let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                return password
            }
            return nil
        }()
        let uris: [PasswordURI]? = {
            guard let urlString = dict["login_uri"]?.nonBlankTrimmedOrNil else { return nil }
            let uri = PasswordURI(uri: urlString, match: .domain)
            return [uri]
        }()

        let mergedNotes = context.mergeNote(notes, with: dict["fields"]?.nonBlankTrimmedOrNil)

        return .login(.init(
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
                notes: mergedNotes,
                iconType: context.makeIconType(uri: uris?.first?.uri),
                uris: uris
            )
        ))
    }

    func parseCSVSecureNote(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"]?.nonBlankTrimmedOrNil
        let noteText = dict["notes"]?.nonBlankTrimmedOrNil

        let text: Data? = {
            if let note = noteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let fieldsInfo = dict["fields"]?.nonBlankTrimmedOrNil

        return .secureNote(.init(
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
                additionalInfo: fieldsInfo
            )
        ))
    }

    func parseCSVCard(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"].formattedName
        let notes = dict["notes"]?.nonBlankTrimmedOrNil

        let cardHolder = dict["card_cardholderName"]?.nonBlankTrimmedOrNil
        let cardNumberString = dict["card_number"]?.nonBlankTrimmedOrNil
        let securityCodeString = dict["card_code"]?.nonBlankTrimmedOrNil

        let expirationDateString: String? = {
            guard let month = dict["card_expMonth"]?.nonBlankTrimmedOrNil,
                  let year = dict["card_expYear"]?.nonBlankTrimmedOrNil else { return nil }
            let yearSuffix = year.count > 2 ? String(year.suffix(2)) : year
            return "\(month)/\(yearSuffix)"
        }()

        let cardNumber: Data? = {
            if let value = cardNumberString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let expirationDate: Data? = {
            if let value = expirationDateString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let securityCode: Data? = {
            if let value = securityCodeString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString) ?? dict["card_brand"]?.nonBlankTrimmedOrNil

        let mergedNotes = context.mergeNote(notes, with: dict["fields"]?.nonBlankTrimmedOrNil)

        return .paymentCard(.init(
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
                cardHolder: cardHolder,
                cardIssuer: cardIssuer,
                cardNumber: cardNumber,
                cardNumberMask: cardNumberMask,
                expirationDate: expirationDate,
                securityCode: securityCode,
                notes: mergedNotes
            )
        ))
    }
}

// MARK: - JSON Parsing

private extension ExternalServiceImportInteractor.BitWardenImporter {

    func formatCustomFields(_ fields: [BitWarden.Field]?) -> String? {
        guard let fields, !fields.isEmpty else { return nil }
        let formatted = fields.compactMap { field -> String? in
            // Skip link fields (type 2)
            guard field.type != 3 else { return nil }
            guard let name = field.name, !name.isEmpty else { return nil }
            let value = field.value ?? ""
            return "\(name): \(value)"
        }
        return formatted.isEmpty ? nil : formatted.joined(separator: "\n")
    }

    func parseLogin(
        login: BitWarden.Login,
        item: BitWarden.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.name?.nonBlankTrimmedOrNil
        let notes = item.notes?.nonBlankTrimmedOrNil
        let username = login.username?.nonBlankTrimmedOrNil
        let password: Data? = {
            if let passwordString = login.password?.nonBlankOrNil,
               let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                return password
            }
            return nil
        }()
        let uris: [PasswordURI]? = {
            guard let uriList = login.uris else {
                return nil
            }
            let urisList: [PasswordURI] = uriList.compactMap { uriEntry in
                guard let uri = uriEntry.uri, !uri.isEmpty else {
                    return nil
                }
                let match: PasswordURI.Match = {
                    switch uriEntry.match {
                    case 0: .domain
                    case 1: .host
                    case 2: .startsWith
                    case 3: .exact
                    default: .domain
                    }
                }()
                return PasswordURI(uri: uri, match: match)
            }
            guard !urisList.isEmpty else {
                return nil
            }
            return urisList
        }()

        // Additional info from login data (excluding used fields) and custom fields
        let loginAdditionalInfo = context.formatDictionary(login.unknownData)
        let fieldsInfo = formatCustomFields(item.fields)
        let additionalInfo = context.mergeNote(loginAdditionalInfo, with: fieldsInfo)
        let mergedNotes = context.mergeNote(notes, with: additionalInfo)

        let creationDate = item.creationDate ?? .importPasswordPlaceholder
        let modificationDate = item.revisionDate ?? .importPasswordPlaceholder

        return .login(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                username: username,
                password: password,
                notes: mergedNotes,
                iconType: context.makeIconType(uri: uris?.first?.uri),
                uris: uris
            )
        ))
    }

    func parseSecureNote(
        secureNote: BitWarden.SecureNote,
        item: BitWarden.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.name.formattedName
        let noteText = item.notes?.nonBlankTrimmedOrNil

        let text: Data? = {
            if let note = noteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let secureNoteInfo = context.formatDictionary(secureNote.unknownData)
        let fieldsInfo = formatCustomFields(item.fields)
        let additionalInfo = context.mergeNote(secureNoteInfo, with: fieldsInfo)

        let creationDate = item.creationDate ?? .importPasswordPlaceholder
        let modificationDate = item.revisionDate ?? .importPasswordPlaceholder

        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
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
    }

    func parseCard(
        card: BitWarden.Card,
        item: BitWarden.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.name.formattedName
        let notes = item.notes?.nonBlankTrimmedOrNil

        let cardHolder = card.cardholderName?.nonBlankTrimmedOrNil
        let cardNumberString = card.number?.nonBlankTrimmedOrNil
        let securityCodeString = card.code?.nonBlankTrimmedOrNil

        let expirationDateString: String? = {
            guard let month = card.expMonth?.nonBlankTrimmedOrNil,
                  let year = card.expYear?.nonBlankTrimmedOrNil else { return nil }
            let yearSuffix = year.count > 2 ? String(year.suffix(2)) : year
            return "\(month)/\(yearSuffix)"
        }()

        let cardNumber: Data? = {
            if let value = cardNumberString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let expirationDate: Data? = {
            if let value = expirationDateString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let securityCode: Data? = {
            if let value = securityCodeString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString) ?? card.brand?.nonBlankTrimmedOrNil

        let cardAdditionalInfo = context.formatDictionary(card.unknownData)
        let fieldsInfo = formatCustomFields(item.fields)
        let additionalInfo = context.mergeNote(cardAdditionalInfo, with: fieldsInfo)
        let mergedNotes = context.mergeNote(notes, with: additionalInfo)

        let creationDate = item.creationDate ?? .importPasswordPlaceholder
        let modificationDate = item.revisionDate ?? .importPasswordPlaceholder

        return .paymentCard(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                cardHolder: cardHolder,
                cardIssuer: cardIssuer,
                cardNumber: cardNumber,
                cardNumberMask: cardNumberMask,
                expirationDate: expirationDate,
                securityCode: securityCode,
                notes: mergedNotes
            )
        ))
    }

    func parseAsSecureNote(
        item: BitWarden.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        contentTypeName: String,
        data: [String: AnyCodable]?,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name: String = {
            var output = ""
            if let name = item.name.formattedName {
                output.append("\(name) ")
            }
            return output + "(\(contentTypeName))"
        }()

        let dataInfo = context.formatDictionary(
            data?.mapValues { $0.value } ?? [:]
        )
        let fieldsInfo = formatCustomFields(item.fields)
        let additionalInfo = context.mergeNote(dataInfo, with: fieldsInfo)
        let noteText = context.mergeNote(additionalInfo, with: item.notes?.nonBlankTrimmedOrNil)

        let text: Data? = {
            if let note = noteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let creationDate = item.creationDate ?? .importPasswordPlaceholder
        let modificationDate = item.revisionDate ?? .importPasswordPlaceholder

        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                text: text,
                additionalInfo: nil
            )
        ))
    }
}

// MARK: - BitWarden Format Models

private struct BitWarden: Decodable {
    let encrypted: Bool
    let folders: [Folder]?
    let items: [Item]?

    struct Folder: Decodable {
        let id: String
        let name: String
    }

    struct Item: Decodable {
        typealias SSHKey = [String: AnyCodable]
        typealias Login = [String: AnyCodable]
        typealias SecureNote = [String: AnyCodable]
        typealias Card = [String: AnyCodable]
        typealias Identity = [String: AnyCodable]
        
        let name: String?
        let notes: String?
        let type: ItemType
        let folderId: String?
        let creationDate: Date?
        let revisionDate: Date?
        let fields: [Field]?
        let login: Login?
        let secureNote: SecureNote?
        let card: Card?
        let identity: Identity?
        let sshKey: SSHKey?
    }

    enum ItemType: Int, Decodable {
        case login = 1
        case secureNote = 2
        case card = 3
        case identity = 4
        case sshKey = 5
        case unknown = 0

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(Int.self)
            self = ItemType(rawValue: rawValue) ?? .unknown
        }
    }

    struct Field: Decodable {
        let name: String?
        let value: String?
        let type: Int?
    }
}

// MARK: - BitWarden Types

private extension BitWarden {

    struct Login {
        static let usedKeys: Set<String> = ["username", "password", "uris", "fido2Credentials"]

        let rawData: [String: Any]?
        let unknownData: [String: Any]

        init(_ rawData: [String: AnyCodable]?) {
            self.rawData = rawData?.mapValues { $0.value }
            self.unknownData = self.rawData?.filter { !Self.usedKeys.contains($0.key) } ?? [:]
        }

        var username: String? {
            rawData?["username"] as? String
        }

        var password: String? {
            rawData?["password"] as? String
        }

        var totp: String? {
            rawData?["totp"] as? String
        }

        var uris: [URI]? {
            guard let uriList = rawData?["uris"] as? [[String: Any]] else {
                return nil
            }
            return uriList.map { URI($0) }
        }

        var fido2Credentials: [[String: Any]]? {
            rawData?["fido2Credentials"] as? [[String: Any]]
        }

        struct URI {
            let rawData: [String: Any]

            init(_ rawData: [String: Any]) {
                self.rawData = rawData
            }

            var uri: String? {
                rawData["uri"] as? String
            }

            var match: Int? {
                rawData["match"] as? Int
            }
        }
    }

    struct SecureNote {
        static let usedKeys: Set<String> = ["type"]

        let rawData: [String: Any]?
        let unknownData: [String: Any]

        init(_ rawData: [String: AnyCodable]?) {
            self.rawData = rawData?.mapValues { $0.value }
            self.unknownData = self.rawData?.filter { !Self.usedKeys.contains($0.key) } ?? [:]
        }

        var type: Int? {
            rawData?["type"] as? Int
        }
    }

    struct Card {
        static let usedKeys: Set<String> = ["cardholderName", "number", "code", "expMonth", "expYear", "brand"]

        let rawData: [String: Any]?
        let unknownData: [String: Any]

        init(_ rawData: [String: AnyCodable]?) {
            self.rawData = rawData?.mapValues { $0.value }
            self.unknownData = self.rawData?.filter { !Self.usedKeys.contains($0.key) } ?? [:]
        }

        var cardholderName: String? {
            rawData?["cardholderName"] as? String
        }

        var brand: String? {
            rawData?["brand"] as? String
        }

        var number: String? {
            rawData?["number"] as? String
        }

        var expMonth: String? {
            rawData?["expMonth"] as? String
        }

        var expYear: String? {
            rawData?["expYear"] as? String
        }

        var code: String? {
            rawData?["code"] as? String
        }
    }

    struct Identity {
        static let usedKeys: Set<String> = []

        let rawData: [String: Any]?
        let unknownData: [String: Any]

        init(_ rawData: [String: AnyCodable]?) {
            self.rawData = rawData?.mapValues { $0.value }
            self.unknownData = self.rawData?.filter { !Self.usedKeys.contains($0.key) } ?? [:]
        }

        var title: String? {
            rawData?["title"] as? String
        }

        var firstName: String? {
            rawData?["firstName"] as? String
        }

        var middleName: String? {
            rawData?["middleName"] as? String
        }

        var lastName: String? {
            rawData?["lastName"] as? String
        }

        var address1: String? {
            rawData?["address1"] as? String
        }

        var address2: String? {
            rawData?["address2"] as? String
        }

        var address3: String? {
            rawData?["address3"] as? String
        }

        var city: String? {
            rawData?["city"] as? String
        }

        var state: String? {
            rawData?["state"] as? String
        }

        var postalCode: String? {
            rawData?["postalCode"] as? String
        }

        var country: String? {
            rawData?["country"] as? String
        }

        var company: String? {
            rawData?["company"] as? String
        }

        var email: String? {
            rawData?["email"] as? String
        }

        var phone: String? {
            rawData?["phone"] as? String
        }

        var ssn: String? {
            rawData?["ssn"] as? String
        }

        var username: String? {
            rawData?["username"] as? String
        }

        var passportNumber: String? {
            rawData?["passportNumber"] as? String
        }

        var licenseNumber: String? {
            rawData?["licenseNumber"] as? String
        }
    }

    struct SSHKey {
        static let usedKeys: Set<String> = []

        let rawData: [String: Any]?
        let unknownData: [String: Any]

        init(_ rawData: [String: AnyCodable]?) {
            self.rawData = rawData?.mapValues { $0.value }
            self.unknownData = self.rawData?.filter { !Self.usedKeys.contains($0.key) } ?? [:]
        }

        var privateKey: String? {
            rawData?["privateKey"] as? String
        }

        var publicKey: String? {
            rawData?["publicKey"] as? String
        }

        var keyFingerprint: String? {
            rawData?["keyFingerprint"] as? String
        }
    }
}
