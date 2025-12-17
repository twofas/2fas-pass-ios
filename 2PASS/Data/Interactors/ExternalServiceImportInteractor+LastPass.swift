// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV

extension ExternalServiceImportInteractor {

    struct LastPassImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let csvString = String(data: content, encoding: .utf8) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            let protectionLevel = context.currentProtectionLevel

            // Track folders for tag creation
            var folderNames: Set<String> = []
            var folderToTagId: [String: ItemTagID] = [:]

            do {
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.header.containsAll(["name", "url", "username", "password", "extra"]) else {
                    throw ExternalServiceImportError.wrongFormat
                }

                // First pass: collect all unique folders
                try csv.enumerateAsDict { dict in
                    if let grouping = dict["grouping"]?.nilIfEmpty {
                        let folders = grouping.split(separator: "\\").map { String($0) }
                        folders.forEach { folderNames.insert($0) }
                    }
                }

                // Create tag IDs for each folder
                for folderName in folderNames {
                    folderToTagId[folderName] = ItemTagID()
                }

                // Second pass: import items
                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    let url = dict["url"]?.nilIfEmpty
                    let extra = dict["extra"]?.nilIfEmpty

                    // Resolve tags from folder hierarchy
                    let tagIds = resolveTagIds(from: dict["grouping"], folderToTagId: folderToTagId)

                    // Check if this is a special item (url = "http://sn")
                    if url == "http://sn", let extra {
                        // Parse the NoteType from extra field
                        let fields = parseExtraFields(from: extra)
                        let noteType = fields["NoteType"]

                        switch noteType {
                        case "Credit Card":
                            if let cardItem = parseCreditCard(
                                dict: dict,
                                fields: fields,
                                vaultID: vaultID,
                                protectionLevel: protectionLevel,
                                tagIds: tagIds
                            ) {
                                items.append(cardItem)
                            }
                        case nil:
                            if let noteItem = parseSecureNote(
                                dict: dict,
                                vaultID: vaultID,
                                protectionLevel: protectionLevel,
                                tagIds: tagIds
                            ) {
                                items.append(noteItem)
                            }
                        default:
                            if let noteItem = parseUnknownTypeAsSecureNote(
                                dict: dict,
                                noteType: noteType,
                                vaultID: vaultID,
                                protectionLevel: protectionLevel,
                                tagIds: tagIds
                            ) {
                                items.append(noteItem)
                                itemsConvertedToSecureNotes += 1
                            }
                        }
                    } else {
                        if let loginItem = parseLogin(
                            dict: dict,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            tagIds: tagIds
                        ) {
                            items.append(loginItem)
                        }
                    }
                }
            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }

            // Create tags from folders
            let tags: [ItemTagData] = folderNames.enumerated().compactMap { index, folderName -> ItemTagData? in
                guard let tagId = folderToTagId[folderName] else { return nil }
                return ItemTagData(
                    tagID: tagId,
                    vaultID: vaultID,
                    name: folderName,
                    color: .gray,
                    position: index,
                    modificationDate: Date()
                )
            }

            return ExternalServiceImportResult(
                items: items,
                tags: tags,
                itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
            )
        }
    }
}

// MARK: - Parsing Helpers

private extension ExternalServiceImportInteractor.LastPassImporter {
    
    func parseLogin(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"].formattedName
        let uris: [PasswordURI]? = {
            guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
            let uri = PasswordURI(uri: urlString, match: .domain)
            return [uri]
        }()
        let username = dict["username"]?.nilIfEmpty
        let password: Data? = {
            if let passwordString = dict["password"]?.nilIfEmpty,
               let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                return password
            }
            return nil
        }()
        let notes = dict["extra"]?.nilIfEmpty
        
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
                notes: notes,
                iconType: context.makeIconType(uri: uris?.first?.uri),
                uris: uris
            )
        ))
    }
    
    func parseCreditCard(
        dict: [String: String],
        fields: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"].formattedName
        
        let cardHolder = fields["Name on Card"]
        let cardNumberString = fields["Number"]
        let securityCodeString = fields["Security Code"]
        let expirationDateString = parseExpirationDate(from: fields["Expiration Date"])
        let notes = fields["Notes"]?.nilIfEmpty
        
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
        let cardIssuer = context.detectCardIssuer(from: cardNumberString)
        
        // Build additional info from unknown extra fields
        let excludedExtraKeys: Set<String> = [
            "NoteType", "Language", "Name on Card", "Type", "Number",
            "Security Code", "Expiration Date", "Notes"
        ]
        let extraAdditionalInfo = context.formatDictionary(fields, excludingKeys: excludedExtraKeys)
        
        // Build additional info from unknown CSV columns
        let knownCSVColumns: Set<String> = [
            "url", "username", "password", "extra", "name", "grouping", "fav"
        ]
        let csvAdditionalInfo = context.formatDictionary(dict, excludingKeys: knownCSVColumns)
        
        // Merge all additional info
        let combinedAdditionalInfo = context.mergeNote(extraAdditionalInfo, with: csvAdditionalInfo)
        let mergedNotes = context.mergeNote(notes, with: combinedAdditionalInfo)
        
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
    
    func parseSecureNote(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"].formattedName
        guard let text = dict["extra"]?.nilIfEmpty else { return nil }
        
        let encryptedText: Data? = {
            if let encrypted = context.encryptSecureField(text, for: protectionLevel) {
                return encrypted
            }
            return nil
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
                text: encryptedText,
                additionalInfo: nil
            )
        ))
    }
    
    func parseUnknownTypeAsSecureNote(
        dict: [String: String],
        noteType: String?,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = dict["name"].formattedName
        guard let extra = dict["extra"]?.nilIfEmpty else { return nil }
        let fields = parseExtraFields(from: extra)
        let displayName = "\(name ?? "Item") (\(noteType ?? "Unknown"))"
        
        let transformedFields = fields.mapValues { value in
            parsePhoneNumber(value) ?? value
        }
        
        let excludedKeys: Set<String> = ["NoteType", "Notes", "Language"]
        let structuredText = context.formatDictionary(transformedFields, excludingKeys: excludedKeys)
        let notes = fields["Notes"]?.nilIfEmpty
        let fullText = context.mergeNote(structuredText, with: notes)
        
        let encryptedText: Data? = {
            guard let text = fullText,
                  let encrypted = context.encryptSecureField(text, for: protectionLevel) else {
                return nil
            }
            return encrypted
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
            name: displayName,
            content: .init(
                name: displayName,
                text: encryptedText,
                additionalInfo: nil
            )
        ))
    }
}

private extension ExternalServiceImportInteractor.LastPassImporter {
    
    func parseExtraFields(from extra: String) -> [String: String] {
        var fields: [String: String] = [:]
        let lines = extra.components(separatedBy: .newlines)

        for line in lines {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colonIndex])
            let value = String(line[line.index(after: colonIndex)...])
            fields[key] = value
        }

        return fields
    }

    func resolveTagIds(from grouping: String?, folderToTagId: [String: ItemTagID]) -> [ItemTagID]? {
        guard let grouping = grouping?.nilIfEmpty else { return nil }
        let folders = grouping.split(separator: "\\").map { String($0) }
        let tagIds = folders.compactMap { folderToTagId[$0] }
        return tagIds.isEmpty ? nil : tagIds
    }
    
    func parsePhoneNumber(_ value: String) -> String? {
        // Parse JSON phone format: {"num":"48404505606","ext":"11","cc3l":"POL"}
        struct PhoneData: Decodable {
            let num: String?
            let ext: String?
        }

        guard let data = value.data(using: .utf8),
              let phone = try? JSONDecoder().decode(PhoneData.self, from: data) else {
            return nil
        }

        var result = phone.num ?? ""
        if let ext = phone.ext.nilIfEmpty {
            result += " ext.\(ext)"
        }
        return result.nilIfEmpty
    }
    
    func parseExpirationDate(from dateString: String?) -> String? {
        // Format: "November,2030" -> "11/30"
        guard let dateString else { return nil }
        let parts = dateString.split(separator: ",")
        guard parts.count == 2,
              let month = monthNumber(from: String(parts[0])),
              let yearString = parts.last else { return nil }
        let year = String(yearString.suffix(2))
        return String(format: "%02d/%@", month, year)
    }

    func monthNumber(from monthName: String) -> Int? {
        let months = [
            "January": 1, "February": 2, "March": 3, "April": 4,
            "May": 5, "June": 6, "July": 7, "August": 8,
            "September": 9, "October": 10, "November": 11, "December": 12
        ]
        return months[monthName]
    }
}
