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

        func importMobile(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let csvString = String(data: content, encoding: .utf8) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            let protectionLevel = context.currentProtectionLevel

            do {
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.header.containsAll(["username", "title", "password", "note", "url"]) else {
                    throw ExternalServiceImportError.wrongFormat
                }

                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    let name = dict["title"].formattedName
                    let uris: [PasswordURI]? = {
                        guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                        let uri = PasswordURI(uri: urlString, match: .domain)
                        return [uri]
                    }()
                    let username = dict["username"]?.nilIfEmpty ?? dict["username2"]?.nilIfEmpty ?? dict["username3"]?.nilIfEmpty
                    let password: Data? = {
                        if let passwordString = dict["password"]?.nilIfEmpty,
                           let password = context.encryptSecureField(passwordString, for: protectionLevel) {
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
                                iconType: context.makeIconType(uri: uris?.first?.uri),
                                uris: uris
                            )
                        ))
                    )
                }

                return items

            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }
        }

        func importDesktop(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let archive = try? Archive(data: content, accessMode: .read, pathEncoding: .utf8) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            let protectionLevel = context.currentProtectionLevel

            // Import credentials
            if let entry = archive.first(where: { $0.path.hasSuffix("credentials.csv") }) {
                let credentialItems = try importCredentialsCSV(from: archive, entry: entry, vaultID: vaultID, protectionLevel: protectionLevel)
                items.append(contentsOf: credentialItems)
            }

            // Import secure notes
            if let entry = archive.first(where: { $0.path.hasSuffix("securenotes.csv") }) {
                let noteItems = try importSecureNotesCSV(from: archive, entry: entry, vaultID: vaultID, protectionLevel: protectionLevel)
                items.append(contentsOf: noteItems)
            }

            // Import payment cards
            if let entry = archive.first(where: { $0.path.hasSuffix("payments.csv") }) {
                let cardItems = try importPaymentsCSV(from: archive, entry: entry, vaultID: vaultID, protectionLevel: protectionLevel)
                items.append(contentsOf: cardItems)
            }

            return items
        }
    }
}

// MARK: - Desktop Import Helpers

private extension ExternalServiceImportInteractor.DashlaneImporter {

    func importCredentialsCSV(
        from archive: Archive,
        entry: Entry,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            var fileData = Data()
            _ = try archive.extract(entry) { data in
                fileData.append(data)
            }

            guard let csvString = String(data: fileData, encoding: .utf8) else {
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

                let note = dict["note"]?.nilIfEmpty

                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: ["title", "url", "username", "password", "note"],
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
                )
            }
        } catch let error as ExternalServiceImportError {
            throw error
        } catch {
            throw .wrongFormat
        }

        return items
    }

    func importSecureNotesCSV(
        from archive: Archive,
        entry: Entry,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            var fileData = Data()
            _ = try archive.extract(entry) { data in
                fileData.append(data)
            }

            guard let csvString = String(data: fileData, encoding: .utf8) else {
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
                    if let noteString = dict["note"]?.nilIfEmpty,
                       let encrypted = context.encryptSecureField(noteString, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()

                let additionalInfo = context.formatDictionary(dict, excludingKeys: ["title", "note"])

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

    func importPaymentsCSV(
        from archive: Archive,
        entry: Entry,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) throws(ExternalServiceImportError) -> [ItemData] {
        var items: [ItemData] = []

        do {
            var fileData = Data()
            _ = try archive.extract(entry) { data in
                fileData.append(data)
            }

            guard let csvString = String(data: fileData, encoding: .utf8) else {
                throw ExternalServiceImportError.wrongFormat
            }
            let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
            guard csv.header.containsAll(["name", "account_holder", "cc_number", "code", "expiration_month", "expiration_year", "note"]) else {
                throw ExternalServiceImportError.wrongFormat
            }

            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let name = dict["name"].formattedName
                let cardHolder = dict["account_holder"]?.nilIfEmpty
                let cardNumberString = dict["cc_number"]?.nilIfEmpty
                let securityCodeString = dict["code"]?.nilIfEmpty
                let expirationMonth = dict["expiration_month"]?.nilIfEmpty
                let expirationYear = dict["expiration_year"]?.nilIfEmpty
                let expirationDateString: String? = {
                    guard let month = expirationMonth, let year = expirationYear?.suffix(2) else { return nil }
                    return "\(month)/\(year)"
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
                let cardIssuer = context.detectCardIssuer(from: cardNumberString)

                let note = dict["note"]?.nilIfEmpty
                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: ["name", "account_holder", "cc_number", "code", "expiration_month", "expiration_year", "note", "type"]
                )
                let notes = context.mergeNote(note, with: additionalInfo)

                items.append(
                    .paymentCard(.init(
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
                            cardHolder: cardHolder,
                            cardIssuer: cardIssuer,
                            cardNumber: cardNumber,
                            cardNumberMask: cardNumberMask,
                            expirationDate: expirationDate,
                            securityCode: securityCode,
                            notes: notes
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
