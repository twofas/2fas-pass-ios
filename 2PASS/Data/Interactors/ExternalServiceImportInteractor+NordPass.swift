// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV

extension ExternalServiceImportInteractor {

    struct NordPassImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let csvString = String(data: content, encoding: .utf8),
                  let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }

            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            let protectionLevel = context.currentProtectionLevel

            // Track unique folder names to create tags
            var folderToTagId: [String: ItemTagID] = [:]
            var tags: [ItemTagData] = []

            do {
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.header.containsAll(["name", "type"]) else {
                    throw ExternalServiceImportError.wrongFormat
                }

                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    let itemType = dict["type"]?.lowercased() ?? ""

                    // Folder definition rows - create tag from folder name
                    if itemType == "folder" {
                        if let folderName = dict["name"]?.nonBlankTrimmedOrNil,
                           folderToTagId[folderName] == nil {
                            let newTagId = ItemTagID()
                            folderToTagId[folderName] = newTagId
                            tags.append(ItemTagData(
                                tagID: newTagId,
                                vaultID: vaultID,
                                name: folderName,
                                color: .unknown(nil),
                                position: tags.count,
                                modificationDate: Date()
                            ))
                        }
                        return
                    }

                    // Handle folder -> tag mapping for items
                    let tagIds: [ItemTagID]? = resolveTagIds(
                        dict: dict,
                        vaultID: vaultID,
                        folderToTagId: &folderToTagId,
                        tags: &tags
                    )

                    switch itemType {
                    case "password":
                        if let loginItem = parseLogin(
                            dict: dict,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            tagIds: tagIds
                        ) {
                            items.append(loginItem)
                        }
                    case "credit_card":
                        if let cardItem = parsePaymentCard(
                            dict: dict,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            tagIds: tagIds
                        ) {
                            items.append(cardItem)
                        }
                    case "note":
                        if let noteItem = parseSecureNote(
                            dict: dict,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            tagIds: tagIds
                        ) {
                            items.append(noteItem)
                        }
                    default:
                        // Convert all unknown types (identity, document, etc.) to secure notes
                        let contentTypeName = itemType.capitalized
                        if let convertedItem = parseAsSecureNote(
                            dict: dict,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            contentTypeName: contentTypeName,
                            tagIds: tagIds
                        ) {
                            items.append(convertedItem)
                            itemsConvertedToSecureNotes += 1
                        }
                    }
                }
            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }

            return ExternalServiceImportResult(
                items: items,
                tags: tags,
                itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
            )
        }
    }
}

// MARK: - Tag Resolution

private extension ExternalServiceImportInteractor.NordPassImporter {

    func resolveTagIds(
        dict: [String: String],
        vaultID: VaultID,
        folderToTagId: inout [String: ItemTagID],
        tags: inout [ItemTagData]
    ) -> [ItemTagID]? {
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
            color: .unknown(nil),
            position: tags.count,
            modificationDate: Date()
        ))
        return [newTagId]
    }
}

// MARK: - Login Parsing

private extension ExternalServiceImportInteractor.NordPassImporter {

    func parseLogin(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"]?.nonBlankTrimmedOrNil
        let notes = dict["note"]?.nonBlankTrimmedOrNil
        let username = dict["username"]?.nonBlankTrimmedOrNil

        let password: Data? = {
            guard let passwordString = dict["password"]?.nonBlankOrNil else { return nil }
            return context.encryptSecureField(passwordString, for: protectionLevel)
        }()

        let uris: [PasswordURI]? = parseURIs(dict: dict)

        // Collect unknown columns using excludingKeys
        let unknownInfo = context.formatDictionary(
            dict,
            excludingKeys: [
                "name", "url", "additional_urls", "username", "password",
                "note", "folder", "type", "custom_fields"
            ]
        )

        // Parse custom fields and merge with notes
        let customFieldsInfo = parseCustomFields(dict["custom_fields"])
        let combinedExtra = context.mergeNote(customFieldsInfo, with: unknownInfo)
        let mergedNotes = context.mergeNote(notes, with: combinedExtra)

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

    func parseURIs(dict: [String: String]) -> [PasswordURI]? {
        var uris: [PasswordURI] = []

        // Primary URL
        if let urlString = dict["url"]?.nonBlankTrimmedOrNil {
            uris.append(PasswordURI(uri: urlString, match: .domain))
        }

        // Additional URLs (JSON array format: ["url1","url2"])
        if let additionalUrlsJson = dict["additional_urls"]?.nonBlankTrimmedOrNil,
           let data = additionalUrlsJson.data(using: .utf8),
           let additionalList = try? JSONDecoder().decode([String].self, from: data) {
            for urlString in additionalList where !urlString.isEmpty {
                uris.append(PasswordURI(uri: urlString, match: .domain))
            }
        }

        return uris.isEmpty ? nil : uris
    }
}

// MARK: - Payment Card Parsing

private extension ExternalServiceImportInteractor.NordPassImporter {

    func parsePaymentCard(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"].formattedName
        let notes = dict["note"]?.nonBlankTrimmedOrNil
        let cardHolder = dict["cardholdername"]?.nonBlankTrimmedOrNil
        let cardNumberString = dict["cardnumber"]?.nonBlankTrimmedOrNil
        let securityCodeString = dict["cvc"]?.nonBlankTrimmedOrNil

        // NordPass uses MM/YY format
        let expirationDateString = dict["expirydate"]?.nonBlankTrimmedOrNil

        let cardNumber: Data? = {
            guard let value = cardNumberString else { return nil }
            return context.encryptSecureField(value, for: protectionLevel)
        }()

        let expirationDate: Data? = {
            guard let value = expirationDateString else { return nil }
            return context.encryptSecureField(value, for: protectionLevel)
        }()

        let securityCode: Data? = {
            guard let value = securityCodeString else { return nil }
            return context.encryptSecureField(value, for: protectionLevel)
        }()

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString)

        // Add PIN and zipcode to notes (not standard fields)
        var additionalInfo: [String] = []
        if let pin = dict["pin"]?.nonBlankTrimmedOrNil {
            additionalInfo.append("PIN: \(pin)")
        }
        if let zipcode = dict["zipcode"]?.nonBlankTrimmedOrNil {
            additionalInfo.append("Zip Code: \(zipcode)")
        }

        let additionalInfoString = additionalInfo.isEmpty ? nil : additionalInfo.joined(separator: "\n")
        let customFieldsInfo = parseCustomFields(dict["custom_fields"])

        // Collect unknown columns
        let unknownInfo = context.formatDictionary(
            dict,
            excludingKeys: [
                "name", "note", "cardholdername", "cardnumber", "cvc",
                "pin", "expirydate", "zipcode", "folder", "type", "custom_fields"
            ]
        )

        let combinedAdditionalInfo = context.mergeNote(additionalInfoString, with: customFieldsInfo)
        let withUnknown = context.mergeNote(combinedAdditionalInfo, with: unknownInfo)
        let mergedNotes = context.mergeNote(notes, with: withUnknown)

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

// MARK: - Secure Note Parsing

private extension ExternalServiceImportInteractor.NordPassImporter {

    func parseSecureNote(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"].formattedName
        let noteText = dict["note"]?.nonBlankTrimmedOrNil

        let text: Data? = {
            guard let note = noteText else { return nil }
            return context.encryptSecureField(note, for: protectionLevel)
        }()

        let customFieldsInfo = parseCustomFields(dict["custom_fields"])

        // Collect unknown columns
        let unknownInfo = context.formatDictionary(
            dict,
            excludingKeys: ["name", "note", "folder", "type", "custom_fields"]
        )
        let additionalInfo = context.mergeNote(customFieldsInfo, with: unknownInfo)

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
                additionalInfo: additionalInfo
            )
        ))
    }

    func parseAsSecureNote(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        contentTypeName: String,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let baseName = dict["name"]?.nonBlankTrimmedOrNil
        let name: String = {
            if let baseName {
                return "\(baseName) (\(contentTypeName))"
            }
            return "(\(contentTypeName))"
        }()

        let notes = dict["note"]?.nonBlankTrimmedOrNil
        let customFieldsInfo = parseCustomFields(dict["custom_fields"])

        // Format all data columns (excluding structural columns)
        let fieldsInfo = context.formatDictionary(
            dict,
            excludingKeys: ["name", "note", "folder", "type", "custom_fields"]
        )

        let combinedInfo = context.mergeNote(fieldsInfo, with: customFieldsInfo)
        let noteText = context.mergeNote(combinedInfo, with: notes)

        let text: Data? = {
            guard let note = noteText else { return nil }
            return context.encryptSecureField(note, for: protectionLevel)
        }()

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
                additionalInfo: nil
            )
        ))
    }
}

// MARK: - Custom Fields Parsing

private extension ExternalServiceImportInteractor.NordPassImporter {

    /// Parses NordPass custom fields from JSON array format
    /// Format: [{"type":"text","label":"Tags","value":"3 tag"},{"type":"date","label":"Date","value":"1772150400"}]
    func parseCustomFields(_ jsonString: String?) -> String? {
        guard let jsonString = jsonString?.nonBlankTrimmedOrNil,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let fields = try context.jsonDecoder.decode([CustomField].self, from: data)
            guard !fields.isEmpty else { return nil }

            let formatted = fields.compactMap { field -> String? in
                guard let label = field.label?.nonBlankTrimmedOrNil else { return nil }
                let value = formatFieldValue(field)
                guard !value.isEmpty else { return nil }
                return "\(label): \(value)"
            }

            return formatted.isEmpty ? nil : formatted.joined(separator: "\n")
        } catch {
            return nil
        }
    }

    func formatFieldValue(_ field: CustomField) -> String {
        guard let value = field.value else { return "" }

        // Date fields are stored as Unix timestamps
        if field.type == "date", let timestamp = Double(value) {
            let date = Date(timeIntervalSince1970: timestamp)
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }

        return value
    }

    struct CustomField: Decodable {
        let type: String?
        let label: String?
        let value: String?
    }
}
