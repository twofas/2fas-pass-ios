// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import ZIPFoundation
import SwiftCSV

extension ExternalServiceImportInteractor {
    
    struct ProtonPassImporter {
        let context: ImportContext
        
        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            // Try to parse as ZIP first (contains JSON)
            if let archive = try? Archive(data: content, accessMode: .read, pathEncoding: .utf8),
               let jsonEntry = archive.first(where: { $0.path.hasSuffix("data.json") }) {
                return try await importFromZIP(archive: archive, jsonEntry: jsonEntry)
            }
            
            // Fallback: try to parse as CSV
            return try await importFromCSV(content)
        }
    }
}

// MARK: - Import Methods

private extension ExternalServiceImportInteractor.ProtonPassImporter {
    
    func importFromZIP(
        archive: Archive,
        jsonEntry: Entry
    ) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
        do {
            var jsonData = Data()
            _ = try archive.extract(jsonEntry) { data in
                jsonData.append(data)
            }
            return try await importFromJSON(jsonData)
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }
    }
    
    func importFromJSON(_ data: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
        guard let vaultID = context.selectedVaultId else {
            throw .wrongFormat
        }
        
        let protectionLevel = context.currentProtectionLevel
        
        do {
            let export = try JSONDecoder().decode(ProtonPassExport.self, from: data)
            
            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            
            for (_, vault) in export.vaults {
                let sourceVaultName = vault.name?.nonBlankTrimmedOrNil
                for item in vault.items {
                    // Skip trashed items (state != 1 means active)
                    guard item.state == 1 else { continue }

                    let creationDate = Date(timeIntervalSince1970: TimeInterval(item.createTime))
                    let modificationDate = Date(timeIntervalSince1970: TimeInterval(item.modifyTime))

                    switch item.data.type {
                    case "login":
                        if let loginItem = importLoginItem(
                            item: item,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            creationDate: creationDate,
                            modificationDate: modificationDate,
                            sourceVaultName: sourceVaultName
                        ) {
                            items.append(loginItem)
                        }

                    case "creditCard":
                        if let cardItem = importCreditCardItem(
                            item: item,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            creationDate: creationDate,
                            modificationDate: modificationDate,
                            sourceVaultName: sourceVaultName
                        ) {
                            items.append(cardItem)
                        }

                    case "note":
                        if let noteItem = importSecureNoteItem(
                            item: item,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            creationDate: creationDate,
                            modificationDate: modificationDate,
                            sourceVaultName: sourceVaultName
                        ) {
                            items.append(noteItem)
                        }

                    default:
                        if let noteItem = importAsSecureNote(
                            item: item,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel,
                            creationDate: creationDate,
                            modificationDate: modificationDate,
                            sourceVaultName: sourceVaultName
                        ) {
                            items.append(noteItem)
                            itemsConvertedToSecureNotes += 1
                        }
                    }
                }
            }
            
            return ExternalServiceImportResult(
                items: items,
                tags: [],
                itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
            )
        } catch {
            throw .wrongFormat
        }
    }
    
    func importFromCSV(_ data: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw .wrongFormat
        }
        guard let vaultID = context.selectedVaultId else {
            throw .wrongFormat
        }
        
        var items: [ItemData] = []
        var itemsConvertedToSecureNotes = 0
        let protectionLevel = context.currentProtectionLevel
        
        do {
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["type", "name", "url", "email", "username", "password", "note"]) else {
                throw ExternalServiceImportError.wrongFormat
            }
            
            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let itemType = dict["type"]?.nonBlankTrimmedOrNil ?? "login"
                let createTimeString = dict["createTime"]?.nonBlankTrimmedOrNil
                let modifyTimeString = dict["modifyTime"]?.nonBlankTrimmedOrNil
                let sourceVaultName = dict["vault"]?.nonBlankTrimmedOrNil

                let creationDate: Date = {
                    if let timeString = createTimeString, let timestamp = TimeInterval(timeString) {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    return Date.importPasswordPlaceholder
                }()

                let modificationDate: Date = {
                    if let timeString = modifyTimeString, let timestamp = TimeInterval(timeString) {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    return Date.importPasswordPlaceholder
                }()

                switch itemType {
                case "login":
                    if let item = importLoginFromCSV(
                        dict: dict,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        creationDate: creationDate,
                        modificationDate: modificationDate,
                        sourceVaultName: sourceVaultName
                    ) {
                        items.append(item)
                    }

                case "creditCard":
                    if let item = importCreditCardFromCSV(
                        dict: dict,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        creationDate: creationDate,
                        modificationDate: modificationDate,
                        sourceVaultName: sourceVaultName
                    ) {
                        items.append(item)
                    }

                case "note":
                    if let item = importSecureNoteFromCSV(
                        dict: dict,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        creationDate: creationDate,
                        modificationDate: modificationDate,
                        sourceVaultName: sourceVaultName
                    ) {
                        items.append(item)
                    }

                default:
                    // identity, custom, sshKey, wifi -> convert to secure note
                    if let item = importAsSecureNoteFromCSV(
                        dict: dict,
                        itemType: itemType,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        creationDate: creationDate,
                        modificationDate: modificationDate,
                        sourceVaultName: sourceVaultName
                    ) {
                        items.append(item)
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
            tags: [],
            itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
        )
    }
}

// MARK: - CSV Import Helpers

private extension ExternalServiceImportInteractor.ProtonPassImporter {
    
    func importLoginFromCSV(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let name = dict["name"]?.nonBlankTrimmedOrNil
        let itemUsername = dict["username"]?.nonBlankTrimmedOrNil
        let itemEmail = dict["email"]?.nonBlankTrimmedOrNil
        let username: String? = itemUsername ?? itemEmail

        let password: Data? = {
            if let passwordString = dict["password"]?.nonBlankOrNil,
               let encrypted = context.encryptSecureField(passwordString, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let uris: [PasswordURI]? = {
            guard let urlString = dict["url"]?.nonBlankTrimmedOrNil
            else { return nil }

            // Split by comma to handle multiple URLs
            let urls = urlString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let passwordURIs = urls.compactMap { url -> PasswordURI? in
                guard !url.isEmpty else { return nil }
                return PasswordURI(uri: url, match: .domain)
            }

            return passwordURIs.isEmpty ? nil : passwordURIs
        }()

        var noteComponents: [String] = []
        if let note = dict["note"]?.nonBlankTrimmedOrNil {
            noteComponents.append(note)
        }
        if itemUsername != nil, let itemEmail {
            noteComponents.append("Email: \(itemEmail)")
        }
        if let totp = dict["totp"]?.nonBlankTrimmedOrNil {
            noteComponents.append("TOTP: \(totp)")
        }
        if let sourceVaultName {
            noteComponents.append("Vault: \(sourceVaultName)")
        }
        let notes = noteComponents.isEmpty ? nil : noteComponents.joined(separator: "\n\n")
        
        return .login(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
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
                iconType: context.makeIconType(uri: uris?.first?.uri),
                uris: uris
            )
        ))
    }
    
    func importCreditCardFromCSV(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let name = dict["name"]?.nonBlankTrimmedOrNil

        // Credit card data is in the "note" field as JSON
        guard let noteJSON = dict["note"]?.nonBlankTrimmedOrNil,
              let jsonData = noteJSON.data(using: .utf8),
              let cardData = try? JSONDecoder().decode(ProtonPassCSVCreditCard.self, from: jsonData) else {
            return nil
        }

        let cardHolder = cardData.cardholderName?.nonBlankTrimmedOrNil
        let cardNumberString = cardData.number?.nonBlankTrimmedOrNil

        let cardNumber: Data? = {
            if let value = cardNumberString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let securityCode: Data? = {
            if let value = cardData.verificationNumber?.nonBlankTrimmedOrNil,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        // Parse expiration date from "YYYY-MM" format to "MM/YY"
        let expirationDateString: String? = {
            guard let expDate = cardData.expirationDate?.nonBlankTrimmedOrNil
            else { return nil }
            let components = expDate.split(separator: "-")
            guard components.count == 2,
                  let year = components.first,
                  let month = components.last else { return expDate }
            let yearSuffix = year.suffix(2)
            return "\(month)/\(yearSuffix)"
        }()

        let expirationDate: Data? = {
            if let value = expirationDateString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString)

        var noteComponents: [String] = []
        if let note = cardData.note?.nonBlankTrimmedOrNil {
            noteComponents.append(note)
        }
        if let pin = cardData.pin?.nonBlankTrimmedOrNil {
            noteComponents.append("Pin: \(pin)")
        }
        if let sourceVaultName {
            noteComponents.append("Vault: \(sourceVaultName)")
        }
        let notes = noteComponents.isEmpty ? nil : noteComponents.joined(separator: "\n\n")

        return .paymentCard(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: nil
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
                notes: notes
            )
        ))
    }

    func importSecureNoteFromCSV(
        dict: [String: String],
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let name = dict["name"]?.nonBlankTrimmedOrNil
        let noteContent = dict["note"]?.nonBlankTrimmedOrNil

        let text: Data? = {
            if let content = noteContent,
               let encrypted = context.encryptSecureField(content, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let additionalInfo = sourceVaultName.map { "Vault: \($0)" }

        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: name,
            content: .init(
                name: name,
                text: text,
                additionalInfo: additionalInfo
            )
        ))
    }
    
    func importAsSecureNoteFromCSV(
        dict: [String: String],
        itemType: String,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let typeName = formatTypeName(itemType)
        let itemName = dict["name"]?.nonBlankTrimmedOrNil
        let name: String = {
            var output = ""
            if let itemName {
                output.append("\(itemName) ")
            }
            return output + "(\(typeName))"
        }()

        var noteComponents: [String] = []

        if let unknownFields = context.formatDictionary(dict, excludingKeys: ["type", "name", "createTime", "modifyTime", "note", "vault"]) {
            noteComponents.append(unknownFields)
        }

        if let noteJSON = dict["note"]?.nonBlankTrimmedOrNil,
           let jsonData = noteJSON.data(using: .utf8),
           let dict = try? JSONDecoder().decode([String: AnyCodable].self, from: jsonData),
           let contentFields = formatContentDictionary(dict) {
            noteComponents.append(contentFields)

        } else if let note = dict["note"]?.nonBlankTrimmedOrNil {
            noteComponents.append(note)
        }

        if let sourceVaultName {
            noteComponents.append("Vault: \(sourceVaultName)")
        }
        
        let noteText = noteComponents.isEmpty ? nil : noteComponents.joined(separator: "\n\n")
        
        let text: Data? = {
            if let content = noteText,
               let encrypted = context.encryptSecureField(content, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()
        
        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
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
    }
    
    func extractIdentityFields(_ identity: ProtonPassCSVIdentity) -> String {
        var fields: [(String, String)] = []

        if let v = identity.fullName?.nonBlankTrimmedOrNil { fields.append(("Full name", v)) }
        if let v = identity.email?.nonBlankTrimmedOrNil { fields.append(("Email", v)) }
        if let v = identity.phoneNumber?.nonBlankTrimmedOrNil { fields.append(("Phone", v)) }
        if let v = identity.organization?.nonBlankTrimmedOrNil { fields.append(("Organization", v)) }
        if let v = identity.streetAddress?.nonBlankTrimmedOrNil { fields.append(("Address", v)) }
        if let v = identity.city?.nonBlankTrimmedOrNil { fields.append(("City", v)) }
        if let v = identity.stateOrProvince?.nonBlankTrimmedOrNil { fields.append(("State/Province", v)) }
        if let v = identity.zipOrPostalCode?.nonBlankTrimmedOrNil { fields.append(("ZIP/Postal code", v)) }
        if let v = identity.countryOrRegion?.nonBlankTrimmedOrNil { fields.append(("Country", v)) }
        if let v = identity.socialSecurityNumber?.nonBlankTrimmedOrNil { fields.append(("SSN", v)) }
        if let v = identity.passportNumber?.nonBlankTrimmedOrNil { fields.append(("Passport number", v)) }
        if let v = identity.licenseNumber?.nonBlankTrimmedOrNil { fields.append(("License number", v)) }
        if let v = identity.website?.nonBlankTrimmedOrNil { fields.append(("Website", v)) }

        return fields.map { "\($0.0): \($0.1)" }.joined(separator: "\n")
    }
}

// MARK: - Item Import Helpers

private extension ExternalServiceImportInteractor.ProtonPassImporter {
    
    func importLoginItem(
        item: ProtonPassItem,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let name = item.data.metadata.name.nonBlankTrimmedOrNil
        let content = ProtonPassLoginContent(item.data.content)

        let itemUsername = content.itemUsername?.nonBlankTrimmedOrNil
        let username: String? = itemUsername ?? content.itemEmail?.nonBlankTrimmedOrNil

        let password: Data? = {
            if let passwordString = content.password?.nonBlankOrNil,
               let encrypted = context.encryptSecureField(passwordString, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let uris: [PasswordURI]? = {
            guard let urls = content.urls, !urls.isEmpty else { return nil }
            return urls.compactMap { urlString -> PasswordURI? in
                guard let url = urlString.nonBlankTrimmedOrNil else { return nil }
                return PasswordURI(uri: url, match: .domain)
            }
        }()

        // Build notes from metadata note + extra fields + TOTP
        var noteComponents: [String] = []
        if let note = item.data.metadata.note.nonBlankTrimmedOrNil {
            noteComponents.append(note)
        }

        let excludingKeys: Set<String> = {
            var keys = ProtonPassLoginContent.usedKeys
            if itemUsername != nil {
                keys.insert("itemEmail")
            }
            return keys
        }()
        if let unknownData = context.formatDictionary(content.rawData, excludingKeys: excludingKeys) {
            noteComponents.append(unknownData)
        }
        if let extraFieldsNote = formatExtraFields(item.data.extraFields) {
            noteComponents.append(extraFieldsNote)
        }
        if let sourceVaultName {
            noteComponents.append("Vault: \(sourceVaultName)")
        }
        let notes = noteComponents.isEmpty ? nil : noteComponents.joined(separator: "\n\n")
        
        return .login(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
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
                iconType: context.makeIconType(uri: uris?.first?.uri),
                uris: uris
            )
        ))
    }
    
    func importCreditCardItem(
        item: ProtonPassItem,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let name = item.data.metadata.name.nonBlankTrimmedOrNil
        let content = ProtonPassCreditCardContent(item.data.content)

        let cardHolder = content.cardholderName?.nonBlankTrimmedOrNil
        let cardNumberString = content.number?.nonBlankTrimmedOrNil

        let cardNumber: Data? = {
            if let value = cardNumberString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let securityCode: Data? = {
            if let value = content.verificationNumber?.nonBlankTrimmedOrNil,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        // Parse expiration date from "YYYY-MM" format to "MM/YY"
        let expirationDateString: String? = {
            guard let expDate = content.expirationDate?.nonBlankTrimmedOrNil
            else { return nil }
            let components = expDate.split(separator: "-")
            guard components.count == 2,
                  let year = components.first,
                  let month = components.last else { return expDate }
            let yearSuffix = year.suffix(2)
            return "\(month)/\(yearSuffix)"
        }()

        let expirationDate: Data? = {
            if let value = expirationDateString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString)

        // Build notes from metadata note + unknown data + extra fields
        var noteComponents: [String] = []
        if let note = item.data.metadata.note.nonBlankTrimmedOrNil {
            noteComponents.append(note)
        }
        if let unknownContentData = context.formatDictionary(content.unknownData) {
            noteComponents.append(unknownContentData)
        }
        if let extraFieldsNote = formatExtraFields(item.data.extraFields) {
            noteComponents.append(extraFieldsNote)
        }
        if let sourceVaultName {
            noteComponents.append("Vault: \(sourceVaultName)")
        }
        let notes = noteComponents.isEmpty ? nil : noteComponents.joined(separator: "\n\n")
        
        return .paymentCard(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: nil
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
                notes: notes
            )
        ))
    }
    
    func importSecureNoteItem(
        item: ProtonPassItem,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let name = item.data.metadata.name.nonBlankTrimmedOrNil

        var additionalInfoComponents: [String] = []
        if let contentFields = formatContentDictionary(item.data.content) {
            additionalInfoComponents.append(contentFields)
        }
        if let extraFieldsNote = formatExtraFields(item.data.extraFields) {
            additionalInfoComponents.append(extraFieldsNote)
        }
        if let sourceVaultName {
            additionalInfoComponents.append("Vault: \(sourceVaultName)")
        }
        let additionalInfo = additionalInfoComponents.isEmpty ? nil : additionalInfoComponents.joined(separator: "\n\n")
        
        let noteContent = item.data.metadata.note.nonBlankTrimmedOrNil
        let text: Data? = {
            if let content = noteContent,
               let encrypted = context.encryptSecureField(content, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()
        
        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: name,
            content: .init(
                name: name,
                text: text,
                additionalInfo: additionalInfo
            )
        ))
    }
    
    func importAsSecureNote(
        item: ProtonPassItem,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        creationDate: Date,
        modificationDate: Date,
        sourceVaultName: String?
    ) -> ItemData? {
        let typeName = formatTypeName(item.data.type)
        let itemName = item.data.metadata.name.nonBlankTrimmedOrNil

        let name: String = {
            var output = ""
            if let itemName {
                output.append("\(itemName) ")
            }
            return output + "(\(typeName))"
        }()

        var noteComponents: [String] = []

        // Add type-specific content
        if let contentFields = formatContentDictionary(item.data.content) {
            noteComponents.append(contentFields)
        }

        // Add extra fields
        if let extraFieldsNote = formatExtraFields(item.data.extraFields) {
            noteComponents.append(extraFieldsNote)
        }

        // Add metadata note
        if let note = item.data.metadata.note.nonBlankTrimmedOrNil {
            noteComponents.append(note)
        }

        // Add source vault name
        if let sourceVaultName {
            noteComponents.append("Vault: \(sourceVaultName)")
        }

        let noteText = noteComponents.isEmpty ? nil : noteComponents.joined(separator: "\n\n")
        
        let text: Data? = {
            if let content = noteText,
               let encrypted = context.encryptSecureField(content, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()
        
        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: creationDate,
                modificationDate: modificationDate,
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
    }
}

// MARK: - Formatting Helpers

private extension ExternalServiceImportInteractor.ProtonPassImporter {
    
    func formatExtraFields(_ extraFields: [ProtonPassExtraField]?) -> String? {
        guard let fields = extraFields, !fields.isEmpty else { return nil }

        let formatted = fields.compactMap { field -> String? in
            let fieldName = field.fieldName
            let value: String?

            switch field.type {
            case "timestamp":
                value = field.data?.timestamp?.nonBlankTrimmedOrNil
            default:
                value = field.data?.content?.nonBlankTrimmedOrNil
            }

            guard let value else { return nil }
            return "\(fieldName): \(value)"
        }

        return formatted.isEmpty ? nil : formatted.joined(separator: "\n")
    }
    
    func formatContentDictionary(_ rawContent: [String: AnyCodable]?) -> String? {
        guard let rawContent else { return nil }
        let dict = rawContent.mapValues { $0.value }
        return context.formatDictionary(dict)
    }
    
    func formatTypeName(_ type: String) -> String {
        type.capitalizedFirstLetter
    }
}

// MARK: - ProtonPass JSON Models

private struct ProtonPassExport: Decodable {
    let vaults: [String: ProtonPassVault]
}

private struct ProtonPassVault: Decodable {
    let name: String?
    let description: String?
    let items: [ProtonPassItem]
}

private struct ProtonPassItem: Decodable {
    let itemId: String?
    let data: ProtonPassItemData
    let state: Int
    let createTime: Int
    let modifyTime: Int
}

private struct ProtonPassItemData: Decodable {
    let metadata: ProtonPassMetadata
    let extraFields: [ProtonPassExtraField]?
    let type: String
    let content: [String: AnyCodable]?
}

private struct ProtonPassMetadata: Decodable {
    let name: String
    let note: String
}

private struct ProtonPassExtraField: Decodable {
    let fieldName: String
    let type: String
    let data: ProtonPassExtraFieldData?
}

private struct ProtonPassExtraFieldData: Decodable {
    let content: String?
    let timestamp: String?
}

// MARK: - Per-Type Content Models

private struct ProtonPassLoginContent {
    static let usedKeys: Set<String> = ["itemEmail", "itemUsername", "password", "urls", "passkeys"]

    let rawData: [String: Any]
    let unknownData: [String: Any]

    init(_ rawData: [String: AnyCodable]?) {
        self.rawData = rawData?.mapValues { $0.value } ?? [:]
        self.unknownData = self.rawData.filter { !Self.usedKeys.contains($0.key) }
    }

    var itemEmail: String? {
        rawData["itemEmail"] as? String
    }

    var itemUsername: String? {
        rawData["itemUsername"] as? String
    }

    var password: String? {
        rawData["password"] as? String
    }

    var urls: [String]? {
        rawData["urls"] as? [String]
    }

    var totpUri: String? {
        rawData["totpUri"] as? String
    }
}

private struct ProtonPassCreditCardContent {
    static let usedKeys: Set<String> = ["cardholderName", "number", "verificationNumber", "expirationDate", "cardType"]

    let rawData: [String: Any]
    let unknownData: [String: Any]

    init(_ rawData: [String: AnyCodable]?) {
        self.rawData = rawData?.mapValues { $0.value } ?? [:]
        self.unknownData = self.rawData.filter { !Self.usedKeys.contains($0.key) }
    }

    var cardholderName: String? {
        rawData["cardholderName"] as? String
    }

    var number: String? {
        rawData["number"] as? String
    }

    var verificationNumber: String? {
        rawData["verificationNumber"] as? String
    }

    var expirationDate: String? {
        rawData["expirationDate"] as? String
    }

    var pin: String? {
        rawData["pin"] as? String
    }
}


// MARK: - ProtonPass CSV Models

private struct ProtonPassCSVCreditCard: Decodable {
    let cardholderName: String?
    let cardType: Int?
    let number: String?
    let verificationNumber: String?
    let expirationDate: String?
    let pin: String?
    let note: String?
}

private struct ProtonPassCSVIdentity: Decodable {
    let fullName: String?
    let email: String?
    let phoneNumber: String?
    let organization: String?
    let streetAddress: String?
    let city: String?
    let stateOrProvince: String?
    let zipOrPostalCode: String?
    let countryOrRegion: String?
    let socialSecurityNumber: String?
    let passportNumber: String?
    let licenseNumber: String?
    let website: String?
    let note: String?
}
