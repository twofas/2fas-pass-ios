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

    struct OnePasswordImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            if let archive = try? Archive(data: content, accessMode: .read, pathEncoding: .utf8) {
                return try await import1Pux(archive)
            }

            return try await importCSV(content)
        }
    }
}

// MARK: - CSV Import

fileprivate extension ExternalServiceImportInteractor.OnePasswordImporter {
    
    func importCSV(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
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

            let requiredHeaders = ["Title", "Url", "Username", "Password", "Notes"]
            guard csv.header.containsAll(requiredHeaders) else {
                throw ExternalServiceImportError.wrongFormat
            }
            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let name = dict["Title"].formattedName
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["Url"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let username = dict["Username"]?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = dict["Password"]?.nilIfEmpty,
                       let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()

                let additionalInfo = context.formatDictionary(
                    dict,
                    excludingKeys: Set(requiredHeaders)
                )
                let notes = context.mergeNote(dict["Notes"]?.nilIfEmpty, with: additionalInfo)

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
}

// MARK: - 1PUX Import

fileprivate extension ExternalServiceImportInteractor.OnePasswordImporter {
    
    func import1Pux(_ archive: Archive) async throws(ExternalServiceImportError) -> [ItemData] {
        guard let vaultID = context.selectedVaultId else {
            throw .wrongFormat
        }

        // Find and extract export.data file
        guard let exportDataEntry = archive.first(where: { $0.path == "export.data" }) else {
            throw .wrongFormat
        }

        var fileData = Data()
        do {
            _ = try archive.extract(exportDataEntry) { data in
                fileData.append(data)
            }
        } catch {
            throw .wrongFormat
        }

        guard let parsedJSON = try? context.jsonDecoder.decode(OnePassword1Pux.self, from: fileData) else {
            throw .wrongFormat
        }

        var items: [ItemData] = []
        let protectionLevel = context.currentProtectionLevel

        for account in parsedJSON.accounts ?? [] {
            for vault in account.vaults ?? [] {
                for item in vault.items ?? [] {
                    // Skip trashed items
                    if item.trashed == true || item.state == "archived" {
                        continue
                    }

                    let categoryUuid = item.categoryUuid ?? ""

                    switch categoryUuid {
                    case OnePassword1Pux.categoryLogin, OnePassword1Pux.categoryPassword:
                        if let loginItem = parseLogin(
                            item: item,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel
                        ) {
                            items.append(loginItem)
                        }

                    case OnePassword1Pux.categorySecureNote:
                        if let noteItem = parseSecureNote(
                            item: item,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel
                        ) {
                            items.append(noteItem)
                        }

                    case OnePassword1Pux.categoryCreditCard:
                        if let cardItem = parseCreditCard(
                            item: item,
                            vaultID: vaultID,
                            protectionLevel: protectionLevel
                        ) {
                            items.append(cardItem)
                        }

                    default:
                        // For other categories, try to import as login if it has login fields
                        if item.details?.loginFields?.isEmpty == false {
                            if let loginItem = parseLogin(
                                item: item,
                                vaultID: vaultID,
                                protectionLevel: protectionLevel
                            ) {
                                items.append(loginItem)
                            }
                        }
                    }
                }
            }
        }

        return items
    }

    private func parseLogin(
        item: OnePassword1Pux.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) -> ItemData? {
        let name = item.overview?.title.formattedName
        let notes = item.details?.notesPlain?.nilIfEmpty

        // Extract username and password from loginFields
        var username: String?
        var passwordString: String?

        for field in item.details?.loginFields ?? [] {
            if field.designation == "username" {
                username = field.value?.nilIfEmpty
            } else if field.designation == "password" {
                passwordString = field.value?.nilIfEmpty
            }
        }

        let password: Data? = {
            if let pwd = passwordString,
               let encrypted = context.encryptSecureField(pwd, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        // Extract URLs
        let uris: [PasswordURI]? = {
            if let urls = item.overview?.urls, !urls.isEmpty {
                let uriList = urls.compactMap { urlEntry -> PasswordURI? in
                    guard let urlString = urlEntry.url?.nilIfEmpty else { return nil }
                    return PasswordURI(uri: urlString, match: .domain)
                }
                return uriList.isEmpty ? nil : uriList
            } else if let urlString = item.overview?.url?.nilIfEmpty {
                return [PasswordURI(uri: urlString, match: .domain)]
            }
            return nil
        }()

        // Extract additional fields from sections
        var additionalFields: [String] = []
        for section in item.details?.sections ?? [] {
            for field in section.fields ?? [] {
                if let title = field.title, let value = field.value?.stringValue, !value.isEmpty {
                    additionalFields.append("\(title): \(value)")
                }
            }
        }
        let additionalInfo = additionalFields.isEmpty ? nil : additionalFields.joined(separator: "\n")
        let mergedNotes = context.mergeNote(notes, with: additionalInfo)

        let creationDate: Date = {
            if let timestamp = item.createdAt {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return .importPasswordPlaceholder
        }()

        let modificationDate: Date = {
            if let timestamp = item.updatedAt {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return .importPasswordPlaceholder
        }()

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
                notes: mergedNotes,
                iconType: context.makeIconType(uri: uris?.first?.uri),
                uris: uris
            )
        ))
    }

    private func parseSecureNote(
        item: OnePassword1Pux.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) -> ItemData? {
        let name = item.overview?.title.formattedName
        let noteText = item.details?.notesPlain?.nilIfEmpty

        let text: Data? = {
            if let note = noteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        // Extract additional fields from sections
        var additionalFields: [String] = []
        for section in item.details?.sections ?? [] {
            for field in section.fields ?? [] {
                if let title = field.title, let value = field.value?.stringValue, !value.isEmpty {
                    additionalFields.append("\(title): \(value)")
                }
            }
        }
        let additionalInfo = additionalFields.isEmpty ? nil : additionalFields.joined(separator: "\n")

        let creationDate: Date = {
            if let timestamp = item.createdAt {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return .importPasswordPlaceholder
        }()

        let modificationDate: Date = {
            if let timestamp = item.updatedAt {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return .importPasswordPlaceholder
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

    private func parseCreditCard(
        item: OnePassword1Pux.Item,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel
    ) -> ItemData? {
        let name = item.overview?.title.formattedName
        let notes = item.details?.notesPlain?.nilIfEmpty

        var cardHolder: String?
        var cardNumberString: String?
        var securityCodeString: String?
        var expirationDateString: String?
        var cardTypeString: String?

        // Extract card details from sections
        for section in item.details?.sections ?? [] {
            for field in section.fields ?? [] {
                let fieldId = field.id ?? ""
                let value = field.value?.stringValue

                switch fieldId {
                case "cardholder":
                    cardHolder = value?.nilIfEmpty
                case "ccnum":
                    // Credit card number can be in creditCardNumber field or as string value
                    cardNumberString = field.value?.creditCardNumber?.nilIfEmpty ?? value?.nilIfEmpty
                case "cvv":
                    securityCodeString = value?.nilIfEmpty
                case "expiry":
                    // 1Password stores expiry as YYYYMM integer
                    if let dateValue = field.value?.date ?? field.value?.monthYear {
                        let year = dateValue / 100
                        let month = dateValue % 100
                        expirationDateString = String(format: "%02d/%02d", month, year % 100)
                    }
                case "type":
                    cardTypeString = field.value?.creditCardType?.nilIfEmpty ?? value?.nilIfEmpty
                default:
                    break
                }
            }
        }

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
        let cardIssuer = context.detectCardIssuer(from: cardNumberString) ?? cardTypeString

        let creationDate: Date = {
            if let timestamp = item.createdAt {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return .importPasswordPlaceholder
        }()

        let modificationDate: Date = {
            if let timestamp = item.updatedAt {
                return Date(timeIntervalSince1970: TimeInterval(timestamp))
            }
            return .importPasswordPlaceholder
        }()

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
}

// MARK: - 1Password 1PUX Format Models

private struct OnePassword1Pux: Decodable {
    let accounts: [Account]?

    struct Account: Decodable {
        let attrs: AccountAttrs?
        let vaults: [Vault]?
    }

    struct AccountAttrs: Decodable {
        let accountName: String?
        let name: String?
        let email: String?
        let uuid: String?
        let domain: String?
    }

    struct Vault: Decodable {
        let attrs: VaultAttrs?
        let items: [Item]?
    }

    struct VaultAttrs: Decodable {
        let uuid: String?
        let name: String?
        let desc: String?
        let type: String?
    }

    struct Item: Decodable {
        let uuid: String?
        let favIndex: Int?
        let createdAt: Int?
        let updatedAt: Int?
        let trashed: Bool?
        let state: String?
        let categoryUuid: String?
        let details: ItemDetails?
        let overview: ItemOverview?
    }

    struct ItemDetails: Decodable {
        let loginFields: [LoginField]?
        let notesPlain: String?
        let sections: [Section]?
        let passwordHistory: [PasswordHistoryEntry]?
    }

    struct LoginField: Decodable {
        let value: String?
        let name: String?
        let fieldType: String?
        let designation: String?
    }

    struct Section: Decodable {
        let title: String?
        let name: String?
        let fields: [SectionField]?
    }

    struct SectionField: Decodable {
        let title: String?
        let id: String?
        let value: SectionFieldValue?
    }

    struct SectionFieldValue: Decodable {
        let concealed: String?
        let string: String?
        let totp: String?
        let date: Int?
        let monthYear: Int?
        let creditCardType: String?
        let creditCardNumber: String?
        let phone: String?
        let url: String?

        private enum CodingKeys: String, CodingKey {
            case concealed, string, totp, date, monthYear, creditCardType, creditCardNumber, phone, url
        }

        init(from decoder: Decoder) throws {
            // Try decoding as a simple string value first
            if let container = try? decoder.singleValueContainer(),
               let stringValue = try? container.decode(String.self) {
                self.string = stringValue
                self.concealed = nil
                self.totp = nil
                self.date = nil
                self.monthYear = nil
                self.creditCardType = nil
                self.creditCardNumber = nil
                self.phone = nil
                self.url = nil
                return
            }

            // Try decoding as a simple int value
            if let container = try? decoder.singleValueContainer(),
               let intValue = try? container.decode(Int.self) {
                self.date = intValue
                self.string = nil
                self.concealed = nil
                self.totp = nil
                self.monthYear = nil
                self.creditCardType = nil
                self.creditCardNumber = nil
                self.phone = nil
                self.url = nil
                return
            }

            // Try decoding as an object with keyed values
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.concealed = try container.decodeIfPresent(String.self, forKey: .concealed)
            self.string = try container.decodeIfPresent(String.self, forKey: .string)
            self.totp = try container.decodeIfPresent(String.self, forKey: .totp)
            self.date = try container.decodeIfPresent(Int.self, forKey: .date)
            self.monthYear = try container.decodeIfPresent(Int.self, forKey: .monthYear)
            self.creditCardType = try container.decodeIfPresent(String.self, forKey: .creditCardType)
            self.creditCardNumber = try container.decodeIfPresent(String.self, forKey: .creditCardNumber)
            self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
            self.url = try container.decodeIfPresent(String.self, forKey: .url)
        }

        var stringValue: String? {
            string ?? concealed ?? totp ?? phone ?? url ?? creditCardNumber ?? creditCardType
        }
    }

    struct PasswordHistoryEntry: Decodable {
        let value: String?
        let time: Int?
    }

    struct ItemOverview: Decodable {
        let title: String?
        let subtitle: String?
        let url: String?
        let urls: [ItemURL]?
        let tags: [String]?
    }

    struct ItemURL: Decodable {
        let label: String?
        let url: String?
    }

    static let categoryLogin = "001"
    static let categoryCreditCard = "002"
    static let categorySecureNote = "003"
    static let categoryPassword = "005"
}
