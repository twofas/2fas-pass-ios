// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension ExternalServiceImportInteractor {

    struct BitWardenImporter {
        let context: ImportContext

        private var decoder: JSONDecoder {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let parsedJSON = try? decoder.decode(BitWarden.self, from: content),
                  parsedJSON.encrypted == false
            else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
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
                    if let loginItem = parseLogin(item: item, vaultID: vaultID, protectionLevel: protectionLevel, tagIds: tagIds) {
                        items.append(loginItem)
                    }
                case .secureNote:
                    if let noteItem = parseSecureNote(item: item, vaultID: vaultID, protectionLevel: protectionLevel, tagIds: tagIds) {
                        items.append(noteItem)
                    }
                case .card:
                    if let cardItem = parseCard(item: item, vaultID: vaultID, protectionLevel: protectionLevel, tagIds: tagIds) {
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
                    }
                case .unknown:
                    break
                }
            }

            return ExternalServiceImportResult(items: items, tags: tags)
        }
    }
}

// MARK: - Parsing

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
        item: BitWarden.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let login = item.login
        let name = item.name.formattedName
        let notes = item.notes?.nilIfEmpty
        let username = (login?["username"]?.value as? String)?.nilIfEmpty
        let password: Data? = {
            if let passwordString = (login?["password"]?.value as? String)?.nilIfEmpty,
               let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                return password
            }
            return nil
        }()
        let uris: [PasswordURI]? = {
            guard let uriList = login?["uris"]?.value as? [[String: Any]] else {
                return nil
            }
            let urisList: [PasswordURI] = uriList.compactMap { uriEntry in
                guard let uri = uriEntry["uri"] as? String, !uri.isEmpty else {
                    return nil
                }
                let match: PasswordURI.Match = {
                    switch uriEntry["match"] as? Int {
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
        let loginAdditionalInfo = context.formatDictionary(
            login?.mapValues { $0.value } ?? [:],
            excludingKeys: ["username", "password", "uris", "fido2Credentials"]
        )
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
        item: BitWarden.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.name.formattedName
        let noteText = item.notes?.nilIfEmpty

        let text: Data? = {
            if let note = noteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()
        
        let secureNoteInfo = context.formatDictionary(
            item.secureNote?.mapValues { $0.value } ?? [:],
            excludingKeys: ["type"]
        )
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
        item: BitWarden.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.name.formattedName
        let notes = item.notes?.nilIfEmpty

        let cardHolder = (item.card?["cardholderName"]?.value as? String)?.nilIfEmpty
        let cardNumberString = (item.card?["number"]?.value as? String)?.nilIfEmpty
        let securityCodeString = (item.card?["code"]?.value as? String)?.nilIfEmpty

        let expirationDateString: String? = {
            guard let month = (item.card?["expMonth"]?.value as? String)?.nilIfEmpty,
                  let year = (item.card?["expYear"]?.value as? String)?.nilIfEmpty else { return nil }
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
        let cardIssuer = context.detectCardIssuer(from: cardNumberString) ?? (item.card?["brand"]?.value as? String)?.nilIfEmpty

        let cardAdditionalInfo = context.formatDictionary(
            item.card?.mapValues { $0.value } ?? [:],
            excludingKeys: ["cardholderName", "number", "code", "expMonth", "expYear", "brand"]
        )
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
        let noteText = context.mergeNote(additionalInfo, with: item.notes?.nilIfEmpty)

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
