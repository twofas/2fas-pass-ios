// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension ExternalServiceImportInteractor {

    struct EnpassImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let parsedJSON = try? context.jsonDecoder.decode(Enpass.self, from: content) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            let protectionLevel = context.currentProtectionLevel

            // Create tags from folders
            let folderToTagId: [String: ItemTagID] = (parsedJSON.folders ?? []).reduce(into: [:]) { result, folder in
                result[folder.uuid] = ItemTagID()
            }

            // Build parent lookup for folder hierarchy
            let folderParentMap: [String: String] = (parsedJSON.folders ?? []).reduce(into: [:]) { result, folder in
                if let parentUuid = folder.parentUuid, !parentUuid.isEmpty {
                    result[folder.uuid] = parentUuid
                }
            }

            let tags: [ItemTagData] = (parsedJSON.folders ?? []).enumerated().compactMap { index, folder -> ItemTagData? in
                guard let tagId = folderToTagId[folder.uuid] else { return nil }
                return ItemTagData(
                    tagID: tagId,
                    vaultID: vaultID,
                    name: folder.title,
                    color: .gray,
                    position: index,
                    modificationDate: Date()
                )
            }

            // Helper to get all tag IDs including parent folders
            func resolveAllTagIds(for folderIds: [String]?) -> [ItemTagID]? {
                guard let folderIds, !folderIds.isEmpty else { return nil }
                var allTagIds: Set<ItemTagID> = []

                for folderId in folderIds {
                    var currentId: String? = folderId
                    while let id = currentId {
                        if let tagId = folderToTagId[id] {
                            allTagIds.insert(tagId)
                        }
                        currentId = folderParentMap[id]
                    }
                }

                return allTagIds.isEmpty ? nil : Array(allTagIds)
            }

            parsedJSON.items?.forEach { item in
                guard item.trashed != 1 else { return }

                let tagIds = resolveAllTagIds(for: item.folders)

                switch item.category {
                case "login", "password":
                    if let loginItem = parseLogin(
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(loginItem)
                    }
                case "creditcard":
                    if let cardItem = parseCreditCard(
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(cardItem)
                    }
                case "note":
                    if let noteItem = parseSecureNote(
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(noteItem)
                    }
                default:
                    // finance, identity, and other categories -> secure note
                    if let noteItem = parseAsSecureNote(
                        item: item,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(noteItem)
                        itemsConvertedToSecureNotes += 1
                    }
                }
            }

            return ExternalServiceImportResult(
                items: items,
                tags: tags,
                itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
            )
        }
    }
}

// MARK: - Parsing

private extension ExternalServiceImportInteractor.EnpassImporter {

    func parseLogin(
        item: Enpass.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.title.formattedName
        let notes = item.note?.nilIfEmpty

        var username: String?
        var email: String?
        var password: Data?
        var urlString: String?
        var additionalFields: [(label: String, value: String)] = []

        item.fields?.forEach { field in
            guard field.deleted != 1 else { return }
            guard let value = field.value?.nilIfEmpty else { return }

            switch field.type {
            case "username":
                if username == nil {
                    username = value
                } else {
                    additionalFields.append((field.label ?? "Username", value))
                }
            case "email":
                if email == nil {
                    email = value
                } else {
                    additionalFields.append((field.label ?? "E-mail", value))
                }
            case "password":
                if password == nil {
                    password = context.encryptSecureField(value, for: protectionLevel)
                } else {
                    additionalFields.append((field.label ?? "Password", value))
                }
            case "url":
                if urlString == nil {
                    urlString = value
                } else {
                    additionalFields.append((field.label ?? "URL", value))
                }
            case "section":
                // Skip section headers
                break
            default:
                let label = field.label ?? formatFieldType(field.type)
                additionalFields.append((label, value))
            }
        }

        username = username ?? email

        // If both username and email exist, add email to additional fields
        if username != nil, let email {
            additionalFields.insert((label: "E-mail", value: email), at: 0)
        }
        
        let uris: [PasswordURI]? = {
            guard let urlString else { return nil }
            let uri = PasswordURI(uri: urlString, match: .domain)
            return [uri]
        }()

        let additionalInfo = formatAdditionalFields(additionalFields)
        let mergedNotes = context.mergeNote(notes, with: additionalInfo)

        return .login(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate(from: item),
                modificationDate: modificationDate(from: item),
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

    func parseCreditCard(
        item: Enpass.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.title.formattedName
        let notes = item.note?.nilIfEmpty

        var cardHolder: String?
        var cardNumberString: String?
        var securityCodeString: String?
        var pinString: String?
        var expirationMonth: String?
        var expirationYear: String?
        var additionalFields: [(label: String, value: String)] = []

        item.fields?.forEach { field in
            guard field.deleted != 1 else { return }
            guard let value = field.value?.nilIfEmpty else { return }

            switch field.type {
            case "ccName":
                if cardHolder == nil {
                    cardHolder = value
                } else {
                    additionalFields.append((field.label ?? "Cardholder", value))
                }
            case "ccNumber":
                if cardNumberString == nil {
                    cardNumberString = value
                } else {
                    additionalFields.append((field.label ?? "Card number", value))
                }
            case "ccCvc":
                if securityCodeString == nil {
                    securityCodeString = value
                } else {
                    additionalFields.append((field.label ?? "CVC", value))
                }
            case "ccPin":
                if pinString == nil {
                    pinString = value
                } else {
                    additionalFields.append((field.label ?? "PIN", value))
                }
            case "ccExpiry":
                // Format is usually "MM/YYYY" or "MM/YY"
                let parts = value.split(separator: "/")
                if parts.count == 2 {
                    expirationMonth = String(parts[0])
                    expirationYear = String(parts[1])
                } else {
                    additionalFields.append((field.label ?? "Expiry", value))
                }
            case "section", "ccType":
                // Skip section headers
                break
            case "ccBankname", "ccValidfrom", "ccTxnpassword":
                additionalFields.append((field.label ?? formatFieldType(field.type), value))
            default:
                let label = field.label ?? formatFieldType(field.type)
                additionalFields.append((label, value))
            }
        }

        let cardNumber: Data? = {
            if let value = cardNumberString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let expirationDateString: String? = {
            guard let month = expirationMonth, let year = expirationYear else { return nil }
            let yearSuffix = year.count > 2 ? String(year.suffix(2)) : year
            return "\(month)/\(yearSuffix)"
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

        // Add PIN to additional fields if present
        if let pin = pinString {
            additionalFields.insert((label: "PIN", value: pin), at: 0)
        }

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString)

        let additionalInfo = formatAdditionalFields(additionalFields)
        let mergedNotes = context.mergeNote(notes, with: additionalInfo)

        return .paymentCard(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate(from: item),
                modificationDate: modificationDate(from: item),
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

    func parseSecureNote(
        item: Enpass.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = item.title.formattedName
        let noteText = item.note?.nilIfEmpty

        let text: Data? = {
            if let note = noteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        var additionalFields: [(label: String, value: String)] = []
        item.fields?.forEach { field in
            guard field.deleted != 1 else { return }
            guard field.type != "section" else { return }
            guard let value = field.value?.nilIfEmpty else { return }
            let label = field.label ?? formatFieldType(field.type)
            additionalFields.append((label, value))
        }

        let additionalInfo = formatAdditionalFields(additionalFields)

        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate(from: item),
                modificationDate: modificationDate(from: item),
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

    func parseAsSecureNote(
        item: Enpass.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let categoryName = item.categoryName ?? formatFieldType(item.category)
        let name: String = {
            if let itemName = item.title.formattedName, !itemName.isEmpty {
                return "\(itemName) (\(categoryName))"
            }
            return "(\(categoryName))"
        }()

        var additionalFields: [(label: String, value: String)] = []
        item.fields?.forEach { field in
            guard field.deleted != 1 else { return }
            guard field.type != "section" else { return }
            guard let value = field.value?.nilIfEmpty else { return }
            let label = field.label ?? formatFieldType(field.type)
            additionalFields.append((label, value))
        }

        let additionalInfo = formatAdditionalFields(additionalFields)
        let noteText = context.mergeNote(additionalInfo, with: item.note?.nilIfEmpty)

        let text: Data? = {
            if let note = noteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate(from: item),
                modificationDate: modificationDate(from: item),
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

    func formatAdditionalFields(_ fields: [(label: String, value: String)]) -> String? {
        guard !fields.isEmpty else { return nil }
        let formatted = fields.map { "\($0.label): \($0.value)" }
        return formatted.joined(separator: "\n")
    }

    func creationDate(from item: Enpass.Item) -> Date {
        if let createdAt = item.createdAt {
            return Date(timeIntervalSince1970: createdAt)
        }
        return .importPasswordPlaceholder
    }

    func modificationDate(from item: Enpass.Item) -> Date {
        if let updatedAt = item.updatedAt {
            return Date(timeIntervalSince1970: updatedAt)
        }
        return .importPasswordPlaceholder
    }

    func formatFieldType(_ type: String?) -> String {
        guard let type else { return "Field" }
        return type
            .replacingOccurrences(of: "cc", with: "Card ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: "([a-z])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .capitalizedFirstLetter
    }
}

// MARK: - Enpass Format Models

private struct Enpass: Decodable {
    struct Folder: Decodable {
        let uuid: String
        let title: String
        let parentUuid: String?

        enum CodingKeys: String, CodingKey {
            case uuid
            case title
            case parentUuid = "parent_uuid"
        }
    }

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
        let categoryName: String?
        let fields: [Field]?
        let folders: [String]?
        let trashed: Int?
        let createdAt: TimeInterval?
        let updatedAt: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case title
            case note
            case category
            case categoryName = "category_name"
            case fields
            case folders
            case trashed
            case createdAt
            case updatedAt = "updated_at"
        }
    }

    let folders: [Folder]?
    let items: [Item]?
}
